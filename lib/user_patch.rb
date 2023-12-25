require_dependency 'user'

module UserPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do

      before_save :set_last_updater_principal
      after_save :set_users_list
    end
  end
  # custom_field_values-editable_custom_field_values_with_patch
  module InstanceMethods
    def set_users_list
      CustomField.where({type: "ProjectCustomField", field_format: "list"}).each do |cf|
        if cf.format_store[:custom_action] == "$active_users"
          cf.possible_values = User.where({type:"User", status: 1}).sort.to_a.join("\n")
          cf.save
        end
      end
    end
    def set_last_updater_principal
      cf = self.available_custom_fields.select{ |cf| cf.custom_action.to_s.include?("$user_id")}.first
      self.custom_field_values= { cf.id => User.current.id } unless cf.nil?
    end
  end
end