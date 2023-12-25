require_dependency 'custom_fields_helper'

module CustomFieldsHelperAdd

    def custom_field_tag_with_label_options(name, custom_value, options={})
      # добавлено sim отображение поля недоступноо для редактирования
      #
      tag = custom_field_tag_options(name, custom_value, options)
      tag_id = nil
      ids = tag.scan(/ id="(.+?)"/)
      if ids.size == 1
        tag_id = ids.first.first
      end
      custom_field_label_tag(name, custom_value, options.merge(:for_tag_id => tag_id)) + tag
    end
    def custom_field_tag_options(prefix, custom_value, options={})
      options[:class] = "#{custom_value.custom_field.field_format}_cf"
      custom_value
        .custom_field.format
        .edit_tag(
          self,
          custom_field_tag_id(prefix, custom_value.custom_field),
          custom_field_tag_name(prefix, custom_value.custom_field),
          custom_value, options
          )
    end
end