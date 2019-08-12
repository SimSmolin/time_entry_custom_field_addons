require_dependency 'time_entry_custom_field'

module TimeEntryCustomFieldPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      has_and_belongs_to_many :projects, :join_table => "#{table_name_prefix}custom_fields_projects#{table_name_suffix}", :foreign_key => "custom_field_id"
      has_many :time_entries, :through => :time_entry_custom_values
      safe_attributes 'project_ids'
    end
  end
  module InstanceMethods
    def visible_by?(project, user=User.current)
      super || (roles & user.roles_for_project(project)).present?
    end
    #private :visible_by?

    def visibility_by_project_condition(project_key=nil, user=User.current, id_column=nil)
      sql = super
      id_column ||= id
      project_condition = "EXISTS (SELECT 1 FROM #{CustomField.table_name} ifa WHERE ifa.is_for_all = #{self.class.connection.quoted_true} AND ifa.id = #{id_column})" +
          " OR #{TimeEntry.table_name}.project_id IN (SELECT project_id FROM #{table_name_prefix}custom_fields_projects#{table_name_suffix} WHERE custom_field_id = #{id_column})"

      "((#{sql}) AND (#{project_condition}))"
    end
    #private :visibility_by_project_condition

    def validate_custom_field
      super
      errors.add(:base, l(:label_role_plural) + ' ' + l('activerecord.errors.messages.blank')) unless editable? || roles.present?
    end
    #private :validate_custom_field
  end
end