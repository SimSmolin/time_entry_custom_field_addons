require_dependency 'custom_fields_helper'

module CustomFieldsHelperPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :custom_field_tag_with_label, :custom_field_tag_with_label_with_patch # method "custom_field_tag_with_label" was modify
    end
  end

  module InstanceMethods
    # Return custom field tag with its label tag
    def custom_field_tag_with_label_with_patch(name, custom_value, options={})
      # добавлено sim заполнение поля атрибутом
      #
      custom_value.value = custom_value.to_s.gsub("{:user}", User.current.to_s)
      custom_value.value = custom_value.to_s.gsub("{:estimated_time}", format_hours(@time_entry.hours))
      custom_value.value = custom_value.to_s.gsub("{:time_now}", Time.now.to_s)
      #
      tag = custom_field_tag(name, custom_value)
      tag_id = nil
      ids = tag.scan(/ id="(.+?)"/)
      if ids.size == 1
        tag_id = ids.first.first
      end
      custom_field_label_tag(name, custom_value, options.merge(:for_tag_id => tag_id)) + tag
    end

  end
end