require_dependency 'user'

module UserPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do

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
  end
end