require_dependency 'time_entry_query'

module TimeEntryQueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :available_columns, :available_columns_with_patch # method "available_columns" was modify
    end
  end

  module InstanceMethods
    def available_columns_with_patch
      return @available_columns if @available_columns
      @available_columns = self.class.available_columns.dup
      # next line changed sim
      @available_columns += [QueryAssociationColumn.new(:user,:mail, :caption => :field_mail)]
      @available_columns += TimeEntryCustomField.visible_with_project_id(project_id).map {|cf| QueryCustomFieldColumn.new(cf)  }
      @available_columns += UserCustomField.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:user, cf, :totalable => false) }
      # end changed
      @available_columns += issue_custom_fields.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:issue, cf, :totalable => false) }
      @available_columns += ProjectCustomField.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:project, cf) }
      @available_columns
    end

  end

end