require_dependency 'query'

module QueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :add_custom_fields_filters, :add_custom_fields_filters_with_patch # method "add_custom_fields_filters" was modify
    end
  end

  module InstanceMethods
    def add_custom_fields_filters_with_patch(scope, assoc=nil)
      scope.visible_with_project_id(project_id).where(:is_filter => true).sorted.each do |field|
        add_custom_field_filter(field, assoc)
        if assoc.nil?
          add_chained_custom_field_filters(field)

          if field.format.target_class && field.format.target_class == Version
            add_available_filter "cf_#{field.id}.due_date",
                                 :type => :date,
                                 :field => field,
                                 :name => l(:label_attribute_of_object, :name => l(:field_effective_date), :object_name => field.name)

            add_available_filter "cf_#{field.id}.status",
                                 :type => :list,
                                 :field => field,
                                 :name => l(:label_attribute_of_object, :name => l(:field_status), :object_name => field.name),
                                 :values => Version::VERSION_STATUSES.map{|s| [l("version_status_#{s}"), s] }
          end
        end
      end
    end

  end

end