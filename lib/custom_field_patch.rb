require_dependency 'custom_field'

module CustomFieldPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :validate_custom_value, :validate_custom_value_with_patch # method "validate_custom_value" was modify
    end
  end

  module InstanceMethods
    def validate_custom_value_with_patch(custom_value)
      value = custom_value.value
      errs = format.validate_custom_value(custom_value)

      unless errs.any?
        if value.is_a?(Array)
          if !multiple?
            errs << ::I18n.t('activerecord.errors.messages.invalid')
          end
          # if is_required? && value.detect(&:present?).nil?
          if visible? && is_required? && value.detect(&:present?).nil?
            errs << ::I18n.t('activerecord.errors.messages.blank')
          end
        else
          # if is_required? && value.blank?
          if visible? && is_required? && value.blank?
            errs << ::I18n.t('activerecord.errors.messages.blank')
          end
        end
      end

      errs
    end
  end
end