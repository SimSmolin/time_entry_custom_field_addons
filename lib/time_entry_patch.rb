require_dependency 'time_entry'

module TimeEntryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :editable_custom_field_values, :editable_custom_field_values_with_patch # method "editable_custom_field_values" was modify
      alias_method :visible_custom_field_values, :visible_custom_field_values_with_patch  # method "visible_custom_field_values" was modify
      alias_method :editable_by?, :editable_by_with_patch?  # method "editable_by?" was modify

      validate :validate_time_entry_period_close
    end
  end
  # custom_field_values-editable_custom_field_values_with_patch
  module InstanceMethods
    class CustomFieldValueReadonly < CustomFieldValue

      attr_accessor :readonly

      def initialize(attributes)
        attributes.each do |name, v|
          send "#{name}=", v
        end
      end
    end

    # Returns true if the time entry can be edited by usr, otherwise false
    def editable_by_with_patch?(usr)
      ((usr == self.user && usr.allowed_to?(:edit_own_time_entries, project)) ||
          usr.allowed_to?(:edit_time_entries, project) ||
          usr.allowed_to?(:view_time_entries_without_edit, project)
      ) && !valid_period_close?(self.spent_on)
    end

    def form_only_viewable_by?(usr)
      if !valid_period_close?(self.spent_on)
        if usr.admin || usr.allowed_to?(:edit_time_entries_on_behalf_of, project)
          false
        else
          !(usr == self.user && usr.allowed_to?(:edit_own_time_entries, project)) &&
              !(usr == self.user && usr.allowed_to?(:edit_time_entries, project))
        end
      else
        true
      end
    end

    def list_only_viewable_by?(usr)
      if !valid_period_close?(self.spent_on)
        false
        true if editable_by_with_patch?(usr) && form_only_viewable_by?(usr)
      else
        false
      end
    end

    def editable_custom_field_values_readonly_parse(user=nil)
      user ||= User.current
      read_only = read_only_attribute_names(user)
      visible_custom_field_values(user).map do |value|
        valueReadonly = CustomFieldValueReadonly.new ({
          :custom_field => value.custom_field,
          :customized => value.customized,
          :value =>value.value,
          :value_was =>value.value_was
        })
        # в новом классе наследнике расставляем признак readonly в соответствии с ролью и участием в проекте
        # valueReadonly.readonly = read_only.include?(value.custom_field_id.to_s)
        # но если период закрыт то поля делаем нередактрируемыми по дате и признаку что поле участвует в закрытии периода
        valueReadonly.readonly = ((valueReadonly.custom_field.participant_period_close? && # участвует в закрытии периода
            valid_period_close?(valueReadonly.customized.spent_on)) || # дата уже закрыта?
            !value.custom_field.editable_by?(project, user) ||    # readonly по проект/роль
            valueReadonly.custom_field.always_close?
        )
        valueReadonly
      end
    end

    # define_method :calculate_period_dates, instance_method(:calculate_period_dates)
    def calculate_period_dates(period_close_date, months_ago, dt_now=DateTime.now - 1.hours)
      close_date = period_close_date.to_i || 0
      currently_closed = close_date > DateTime.now.day ? 1:0
      val_setting_months = months_ago.to_i + currently_closed
      if dt_now.day > 15
        begin_period = dt_now.beginning_of_month.next_day(15)
        end_period = dt_now.beginning_of_month + 1.month + val_setting_months.month + close_date.day
      else
        begin_period = dt_now.beginning_of_month
        end_period = dt_now.beginning_of_month + val_setting_months.month + 15.day + close_date.day
      end
      {begin_period: begin_period, end_period: end_period }
    end

    # dt_now часы с отставанием на час - дать время занести трудозатраты москвичам
    def valid_period_close?(date_for_field, dt_now=DateTime.now - 1.hours)
      date_for_field = date_for_field || DateTime.parse('1970-01-01')
      period_close_date = Setting.plugin_time_entry_custom_field_addons['period_close_date'].to_i || 0
      if User.current.roles_for_project(project).reject { |role| !role.permissions.include?(:edit_time_entries_advantage_time) }.present?
        period_close_date = Setting.plugin_time_entry_custom_field_addons['advantage_period_close_date'].to_i || 0
      end
      # begin_period = calculate_period_dates(period_close_date,
      #                                       Setting.plugin_time_entry_custom_field_addons['months_ago'],
      #                                       dt_now )[:begin_period]
      # date_for_field <= begin_period
      end_period = calculate_period_dates(period_close_date,
                                          Setting.plugin_time_entry_custom_field_addons['months_ago'],
                                          date_for_field.to_datetime)[:end_period]
      dt_now > end_period
    end

    def editable_custom_field_values_with_patch(user=nil)
      read_only = read_only_attribute_names(user)
      visible_custom_field_values(user).reject do |value|
        read_only.include?(value.custom_field_id.to_s)
      end
    end

    def visible_custom_field_values_with_patch(user=nil)
      user_real = user || User.current
      custom_field_values.select do |value|
        value.custom_field.visible_by?(project, user_real)
      end
    end

    def read_only_attribute_names(user=nil)
      workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'readonly'}.keys
    end
    private :read_only_attribute_names

    def workflow_rule_by_attribute(user=nil)
      return @workflow_rule_by_attribute if @workflow_rule_by_attribute && user.nil?

      user_real = user || User.current
      roles = user_real.admin ? Role.all.to_a : user_real.roles_for_project(project)
      roles = roles.select(&:consider_workflow?)
      return {} if roles.empty?

      result = {}
      workflow_permissions = WorkflowPermission.where( :role_id => roles.map(&:id)).to_a # changed sim
      if workflow_permissions.size() == 0
        workflow_permissions = WorkflowPermission.where( :role_id => Role.find_by(:name => "Участник").id).to_a
      end
      if workflow_permissions.any?
        workflow_rules = workflow_permissions.inject({}) do |h, wp|
          h[wp.field_name] ||= {}
          h[wp.field_name][wp.role_id] = wp.rule
          h
        end
        fields_with_roles = {}
        TimeEntryCustomField.where(:editable => false).joins(:roles).pluck(:id, "role_id").each do |field_id, role_id|
          fields_with_roles[field_id] ||= []
          fields_with_roles[field_id] << role_id
        end
        roles.each do |role|
          fields_with_roles.each do |field_id, role_ids|
            unless role_ids.include?(role.id)
              field_name = field_id.to_s
              workflow_rules[field_name] ||= {}
              workflow_rules[field_name][role.id] = 'readonly'
            end
          end
        end
        workflow_rules.each do |attr, rules|

          next if rules.size < roles.size
          uniq_rules = rules.values.uniq
          if uniq_rules.size == 1
            result[attr] = uniq_rules.first
          else
            result[attr] = 'required'
          end
        end
      end
      @workflow_rule_by_attribute = result if user.nil?
      result
    end
    private :workflow_rule_by_attribute

    def user_collection_for_select_options
      project ||= self.try(:project)
      collection = []
      collection << [ User.current.name, User.current.id ]
      project_members = []
      project_members = project.members.to_a.map { |memb| [memb.name, memb.user_id]}.sort unless project.nil?
      collection.concat(project_members).uniq
    end

    # Copies attributes from another TimeEntry, arg can be an id or an TimeEntry
    #
    def copy_from(arg)
      time_entry = arg.is_a?(TimeEntry) ? arg : TimeEntry.visible.find(arg)
      self.attributes = time_entry.attributes.dup.except("id", "created_on", "updated_on")
      self.custom_field_values = time_entry.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
      # @copied_from = time_entry
      self
    end

    def validate_time_entry_period_close
      if valid_period_close?(spent_on)
        write_attribute(:spent_on, Date.current)
        errors.add :spent_on, :invalid, :message => l(:error_spent_on_period_close)
      end
    end

  end
end