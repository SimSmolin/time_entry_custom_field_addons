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
      if "time_entry".include?(name.to_s)
        # если пустое то снова подставляем значение по умолчанию
        if custom_value.value.delete(" ").empty?
          custom_value.value=custom_value.custom_field.default_value
        end
        custom_value.value = custom_value.to_s.split(" ", 2)[0].gsub("{:user}", "{:user} " + User.current.to_s)
        if @time_entry.present?
          custom_value.value = custom_value.to_s.gsub("{:estimated_time}", format_hours(@time_entry.hours).gsub(".",","))
        end
        custom_value.value = custom_value.to_s.gsub("{:time_now}", Time.now.strftime("%d.%m.%Y %H:%M") + "(" +User.current.to_s+ ") {:time_now}")
      end
      #
      tag = custom_field_tag(name, custom_value)
      tag_id = nil
      ids = tag.scan(/ id="(.+?)"/)
      if ids.size == 1
        tag_id = ids.first.first
      end
      custom_field_label_tag(name, custom_value, options.merge(:for_tag_id => tag_id)) + tag
    end

    def custom_field_tag_with_label_disabled(name, custom_value, options={})
      # добавлено sim отображение поля недоступноо для редактирования
      #
      if "time_entry".include?(name.to_s)
        custom_value.value= custom_value.to_s.gsub("{:user}", "")
        if @time_entry.present?
          custom_value.value= custom_value.to_s.gsub("{:estimated_time}", "")
        end
        custom_value.value= custom_value.to_s.gsub("{:time_now}", "")
      end
      #
      tag = custom_value.readonly ? custom_field_tag_disabled(name, custom_value):custom_field_tag(name, custom_value)
      tag_id = nil
      ids = tag.scan(/ id="(.+?)"/)
      if ids.size == 1
        tag_id = ids.first.first
      end
      custom_field_label_tag(name, custom_value, options.merge(:for_tag_id => tag_id)) + tag
    end

    def custom_field_tag_disabled(prefix, custom_value)
      custom_value.custom_field.format.edit_tag self,
      custom_field_tag_id(prefix, custom_value.custom_field),
      custom_field_tag_name(prefix, custom_value.custom_field),
      custom_value,
      :class => "#{custom_value.custom_field.field_format}_cf",
      :disabled => "disabled"
    end

  end
end