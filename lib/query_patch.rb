require_dependency 'query'

module QueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :add_custom_fields_filters, :add_custom_fields_filters_with_patch # method "add_custom_fields_filters" was modify
      define_method :role_values, instance_method(:role_values)
      define_method :projects_by_role_values, instance_method(:projects_by_role_values)
    end

    base.operators_by_filter_type[:tree] = ["=", "!", "~", "!*", "*"]
  end

  module InstanceMethods
    def add_custom_fields_filters_with_patch(scope, assoc=nil)
      scope.visible_with_project_id(project_id).where(:is_filter => true).sorted.each do |field|
      # scope.visible.where(:is_filter => true).sorted.each do |field|
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

    def role_values
      project_values = []
      project_values += projects_by_role_values
      project_values
    end

    def projects_by_role_values
      return @projects_by_role_values if @projects_by_role_values

      values = []
      User.current.projects_by_role.map do |role, projects|
        values << ["#{role.name}", role.id.to_s]
      end
      @projects_by_role_values = values
    end



  end
end

module QueryCustomFieldColumnPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :value_object, :value_object_with_patch # method "value_object" was modify
    end
  end

  module InstanceMethods
    def value_object_with_patch(object)
      if object.is_a?(User)
        if custom_field.visible_by?(nil, User.current)
          cv = object.custom_values.select {|v| v.custom_field_id == @cf.id}
          cv.size > 1 ? cv.sort {|a,b| a.value.to_s <=> b.value.to_s} : cv.first
        else
          nil
        end
      else
        if custom_field.visible_by?(object.project, User.current)
          cv = object.custom_values.select {|v| v.custom_field_id == @cf.id}
          cv.size > 1 ? cv.sort {|a,b| a.value.to_s <=> b.value.to_s} : cv.first
        else
          nil
        end
      end
    end
  end
end