require_dependency 'time_entry_query'

module TimeEntryQueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :available_columns, :available_columns_with_patch # method "available_columns" was modify
      alias_method :base_scope, :base_scope_with_patch
      alias_method :sql_for_issue_id_field, :sql_for_issue_id_field_patch
      alias_method :initialize_available_filters, :initialize_available_filters_patch
      define_method :sql_for_role_id_field, instance_method(:sql_for_role_id_field)
    end
  end

  module InstanceMethods
    def available_columns_with_patch
      return @available_columns if @available_columns
      @available_columns = self.class.available_columns.dup
      # next line changed sim
      @available_columns += [QueryAssociationColumn.new(:issue,:fixed_version, :caption => :field_fixed_version)]
      @available_columns += [QueryAssociationColumn.new(:user,:mail, :caption => :field_mail)]
      @available_columns += TimeEntryCustomField.visible_with_project_id(project_id).map {|cf| QueryCustomFieldColumn.new(cf)  }
      # @available_columns += TimeEntryCustomField.visible.map {|cf| QueryCustomFieldColumn.new(cf)  }
      @available_columns += UserCustomField.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:user, cf, :totalable => false) }
      # end changed
      @available_columns += issue_custom_fields.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:issue, cf, :totalable => false) }
      @available_columns += ProjectCustomField.visible.
          map {|cf| QueryAssociationCustomFieldColumn.new(:project, cf) }
      @available_columns
    end

    def base_scope_with_patch
      TimeEntry.visible.
          joins(:project, :user).
          includes(:activity).
          references(:activity).
          left_join_issue.
          where(statement_correct_spent_on)
    end

    def statement_correct_spent_on
      # filters clauses
      filters_clauses = []
      filters.each_key do |field|
        next if field == "subproject_id"
        v = values_for(field).clone
        next unless v and !v.empty?
        operator = operator_for(field)

        # "me" value substitution
        if %w(assigned_to_id author_id user_id watcher_id updated_by last_updated_by).include?(field)
          if v.delete("me")
            if User.current.logged?
              v.push(User.current.id.to_s)
              v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
            else
              v.push("0")
            end
          end
        end

        if field == 'project_id'
          if v.delete('mine')
            v += User.current.memberships.map(&:project_id).map(&:to_s)
          end
        end

        if field =~ /^cf_(\d+)\.cf_(\d+)$/
          filters_clauses << sql_for_chained_custom_field(field, operator, v, $1, $2)
        elsif field =~ /cf_(\d+)$/
          # custom field
          filters_clauses << sql_for_custom_field(field, operator, v, $1)
        elsif field =~ /^cf_(\d+)\.(.+)$/
          filters_clauses << sql_for_custom_field_attribute(field, operator, v, $1, $2)
        elsif respond_to?(method = "sql_for_#{field.gsub('.','_')}_field")
          # specific statement
          filters_clauses << send(method, field, operator, v)
        else
          # regular field
          filters_clauses << '(' + sql_for_field(field, operator, v, queried_table_name, field, false) + ')'
        end
      end if filters and valid?

      if (c = group_by_column) && c.is_a?(QueryCustomFieldColumn)
        # Excludes results for which the grouped custom field is not visible
        filters_clauses << c.custom_field.visibility_by_project_condition
      end

      filters_clauses << project_statement
      filters_clauses.reject!(&:blank?)

      filters_clauses.any? ? filters_clauses.join(' AND ') : nil
    end

  end

  def sql_for_issue_id_field_patch(field, operator, value)
    case operator
    when "="
      "#{TimeEntry.table_name}.issue_id = #{value.first.to_i}"
    when "!"
      "NOT #{TimeEntry.table_name}.issue_id = #{value.first.to_i}"
    when "~"
      issue = Issue.where(:id => value.first.to_i).first
      if issue && (issue_ids = issue.self_and_descendants.pluck(:id)).any?
        "#{TimeEntry.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!*"
      "#{TimeEntry.table_name}.issue_id IS NULL"
    when "*"
      "#{TimeEntry.table_name}.issue_id IS NOT NULL"
    end
  end

  def sql_for_role_id_field(field, operator, value)
    value = User.current.projects_by_role[Role.find(value[0].to_i)].map(&:id)
    '(' + sql_for_field(field, operator, value, queried_table_name, "project_id", true) + ')'
  end

  def initialize_available_filters_patch
    add_available_filter "spent_on", :type => :date_past

    add_available_filter("project_id",
                         :type => :list, :values => lambda { project_values }
    ) if project.nil?

    add_available_filter("role_id", :name => l(:field_role),
                         :type => :list, :values => lambda { role_values }
    ) if project.nil?

    if project && !project.leaf?
      add_available_filter "subproject_id",
                           :type => :list_subprojects,
                           :values => lambda { subproject_values }
    end

    add_available_filter("issue_id", :type => :tree, :label => :label_issue)
    add_available_filter("issue.tracker_id",
                         :type => :list,
                         :name => l("label_attribute_of_issue", :name => l(:field_tracker)),
                         :values => lambda { trackers.map {|t| [t.name, t.id.to_s]} })
    add_available_filter("issue.status_id",
                         :type => :list,
                         :name => l("label_attribute_of_issue", :name => l(:field_status)),
                         :values => lambda { issue_statuses_values })
    add_available_filter("issue.fixed_version_id",
                         :type => :list,
                         :name => l("label_attribute_of_issue", :name => l(:field_fixed_version)),
                         :values => lambda { fixed_version_values })

    add_available_filter("user_id",
                         :type => :list_optional, :values => lambda { author_values }
    )

    activities = (project ? project.activities : TimeEntryActivity.shared)
    add_available_filter("activity_id",
                         :type => :list, :values => activities.map {|a| [a.name, a.id.to_s]}
    )

    add_available_filter "comments", :type => :text
    add_available_filter "hours", :type => :float

    add_custom_fields_filters(TimeEntryCustomField)
    add_associations_custom_fields_filters :project
    add_custom_fields_filters(issue_custom_fields, :issue)
    add_associations_custom_fields_filters :user
  end

end