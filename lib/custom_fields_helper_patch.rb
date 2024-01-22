module CustomFieldsHelperPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :custom_field_tag, :custom_field_tag_patch # method "validate_custom_value" was modify
      alias_method :custom_field_name_tag, :custom_field_name_tag_patch
    end
  end
  module InstanceMethods
    def custom_field_tag_patch(prefix, custom_value)
      style = "resize:both" if custom_value.custom_field.multiple?
      custom_value.custom_field.format.edit_tag self,
        custom_field_tag_id(prefix, custom_value.custom_field),
        custom_field_tag_name(prefix, custom_value.custom_field),
        custom_value,
        :class => "#{custom_value.custom_field.field_format}_cf",
        :style => style
    end

    def custom_field_name_tag_patch(custom_field)
      title = custom_field.description.presence
      css = title ? "field-description" : nil
      tag_name = l(custom_field.name).to_s.include?("translation missing:")? custom_field.name : l(custom_field.name)
      content_tag 'span', tag_name, :title => title, :class => css
    end

  end

end