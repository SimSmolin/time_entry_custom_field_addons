require_dependency 'custom_field'

module CustomFieldPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :validate_custom_value, :validate_custom_value_with_patch # method "validate_custom_value" was modify

      # added sim
      #
      safe_attributes 'participant_period_close'

      scope :visible_with_project_id, lambda {|*args|
        user = User.current
        project_id = args.shift || 0
        if user.admin?
          # nop
        elsif user.memberships.any?
          where("#{table_name}.visible = ? OR #{table_name}.id IN (SELECT DISTINCT cfr.custom_field_id FROM #{Member.table_name} m" +
                    " INNER JOIN #{MemberRole.table_name} mr ON mr.member_id = m.id" +
                    " INNER JOIN #{table_name_prefix}custom_fields_roles#{table_name_suffix} cfr ON cfr.role_id = mr.role_id" +
                    " WHERE m.user_id = ? AND m.project_id = ?)" +
                    " AND (" +
                    "NOT (#{table_name}.type = 'TimeEntryCustomField') OR " +
                    "(#{table_name}.is_for_all = TRUE OR #{project_id} IN (SELECT project_id FROM #{table_name_prefix}custom_fields_projects#{table_name_suffix} cfp WHERE cfp.custom_field_id = #{table_name}.id))" +
                    ")",
                # AND (NOT (`custom_fields`.`type` = 'TimeEntryCustomField') OR  (is_for_all = TRUE OR  139 IN (SELECT project_id FROM custom_fields_projects WHERE custom_field_id = id)))
                true, user.id, project_id)
        else
          where(:visible => true)
        end
      }
      # вот этот изврат изза того что after_save в основном классе сделано без метода (def)
      # перед сохранением запоминаем состояние roles а потом восстанавливаем
      @records_roles = nil
      before_save do |field|
        @records_roles = field.roles.to_a
      end
      after_save do |field|
        begin
        field.roles << @records_roles unless @records_roles.nil?
        rescue

        end
      end

      # end added block
    end
  end

  module InstanceMethods
    def validate_custom_value_with_patch(custom_value)
      value = custom_value.value
      errs = format.validate_custom_value(custom_value)
      if custom_value.customized.is_a?(TimeEntry)
        unless errs.any?
          if value.is_a?(Array)
            if !multiple?
              errs << ::I18n.t('activerecord.errors.messages.invalid')
            end
            # if is_required? && value.detect(&:present?).nil?
            if custom_value.custom_field.visible_by?(Project.find_by_id(custom_value.customized.project_id), User.current) && is_required? && value.detect(&:present?).nil?
              errs << ::I18n.t('activerecord.errors.messages.blank')
            end
          else
            # if is_required? && value.blank?
            if custom_value.custom_field.visible_by?(Project.find_by_id(custom_value.customized.project_id), User.current) && is_required? && value.blank?
              errs << ::I18n.t('activerecord.errors.messages.blank')
            end
          end
        end
      else
        unless errs.any?
          if value.is_a?(Array)
            if !multiple?
              errs << ::I18n.t('activerecord.errors.messages.invalid')
            end
            if is_required? && value.detect(&:present?).nil?
              errs << ::I18n.t('activerecord.errors.messages.blank')
            end
          else
            if is_required? && value.blank?
              errs << ::I18n.t('activerecord.errors.messages.blank')
            end
          end
        end
      end

      errs
    end
  end

  def participant_period_close?
    participant_period_close == '1'
  end

end