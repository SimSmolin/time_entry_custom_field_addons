require_dependency 'time_entry'

module TimeEntryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method_chain :editable_custom_field_values, :patch # method "editable_custom_field_values" was modify
      alias_method_chain :visible_custom_field_values, :patch  # method "visible_custom_field_values" was modify
    end
  end

  module InstanceMethods
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
      if workflow_permissions.any?
        workflow_rules = workflow_permissions.inject({}) do |h, wp|
          h[wp.field_name] ||= {}
          h[wp.field_name][wp.role_id] = wp.rule
          h
        end
        fields_with_roles = {}
        TimeEntryCustomField.where(:visible => false).joins(:roles).pluck(:id, "role_id").each do |field_id, role_id|
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

  end
end