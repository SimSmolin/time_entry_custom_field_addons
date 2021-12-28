require_dependency 'issue_query'

module IssueQueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :available_columns, :available_columns_with_patch # method "available_columns" was modify
      alias_method_chain :issues, :load_remaining_hours
    end
  end

  module InstanceMethods
    def available_columns_with_patch
      return @available_columns if @available_columns
      @available_columns = self.class.available_columns.dup
      @available_columns += issue_custom_fields.visible.collect {|cf| QueryCustomFieldColumn.new(cf) }

      if User.current.allowed_to?(:view_time_entries, project, :global => true)
        # insert the columns after total_estimated_hours or at the end
        index = @available_columns.find_index {|column| column.name == :total_estimated_hours}
        index = (index ? index + 1 : -1)

        subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
          " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
          " WHERE (#{TimeEntry.visible_condition(User.current)}) AND #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id"

        @available_columns.insert index, QueryColumn.new(:spent_hours,
                                                         :sortable => "COALESCE((#{subselect}), 0)",
                                                         :default_order => 'desc',
                                                         :caption => :label_spent_time,
                                                         :totalable => true
        )

        subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
          " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
          " JOIN #{Issue.table_name} subtasks ON subtasks.id = #{TimeEntry.table_name}.issue_id" +
          " WHERE (#{TimeEntry.visible_condition(User.current)})" +
          " AND subtasks.root_id = #{Issue.table_name}.root_id AND subtasks.lft >= #{Issue.table_name}.lft AND subtasks.rgt <= #{Issue.table_name}.rgt"

        @available_columns.insert index+1, QueryColumn.new(:total_spent_hours,
                                                           :sortable => "COALESCE((#{subselect}), 0)",
                                                           :default_order => 'desc',
                                                           :caption => :label_total_spent_time
        )
      #  добавлено sim для расчета оставшихся трудозатрат
        subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
          " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
          " WHERE (#{TimeEntry.visible_condition(User.current)}) AND #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id"

        @available_columns.insert index+2, QueryColumn.new(:remaining_hours,
                                                         :sortable => "COALESCE(estimated_hours, 0) - COALESCE((#{subselect}), 0)",
                                                         :default_order => 'desc',
                                                         :caption => :label_remaining_time,
        )

        subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
          " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
          " JOIN #{Issue.table_name} subtasks ON subtasks.id = #{TimeEntry.table_name}.issue_id" +
          " WHERE (#{TimeEntry.visible_condition(User.current)})" +
          " AND subtasks.root_id = #{Issue.table_name}.root_id AND subtasks.lft >= #{Issue.table_name}.lft AND subtasks.rgt <= #{Issue.table_name}.rgt"
        subselect_1 = "SELECT SUM(estimated_hours) FROM #{Issue.table_name} subtasks" +
            " WHERE #{Issue.visible_condition(User.current).gsub(/\bissues\b/, 'subtasks')}" +
            " AND subtasks.root_id = #{Issue.table_name}.root_id" +
            " AND subtasks.lft >= #{Issue.table_name}.lft AND subtasks.rgt <= #{Issue.table_name}.rgt"
        @available_columns.insert index+3, QueryColumn.new(:total_remaining_hours,
                                                           :sortable => "COALESCE((#{subselect_1}), 0) - COALESCE((#{subselect}), 0)",
                                                           :default_order => 'desc',
                                                           :caption => :label_total_remaining_time
        )

      end

      if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
        User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
        @available_columns << QueryColumn.new(:is_private, :sortable => "#{Issue.table_name}.is_private", :groupable => true)
      end

      disabled_fields = Tracker.disabled_core_fields(trackers).map {|field| field.sub(/_id$/, '')}
      disabled_fields << "total_estimated_hours" if disabled_fields.include?("estimated_hours")
      @available_columns.reject! {|column|
        disabled_fields.include?(column.name.to_s)
      }

      @available_columns
    end

    def issues_with_load_remaining_hours (options={})
      order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

      scope = Issue.visible.
        joins(:status, :project).
        preload(:priority).
        where(statement).
        includes(([:status, :project] + (options[:include] || [])).uniq).
        where(options[:conditions]).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(','))).
        limit(options[:limit]).
        offset(options[:offset])

      scope = scope.preload([:tracker, :author, :assigned_to, :fixed_version, :category, :attachments] & columns.map(&:name))
      if has_custom_field_column?
        scope = scope.preload(:custom_values)
      end

      issues = scope.to_a

      if has_column?(:spent_hours)
        Issue.load_visible_spent_hours(issues)
      end
      if has_column?(:total_spent_hours)
        Issue.load_visible_total_spent_hours(issues)
      end
      # if has_column?(:remaining_hours)
        Issue.load_visible_remaining_hours(issues)
      # end
      # if has_column?(:total_remaining_hours)
        Issue.load_visible_total_remaining_hours(issues)
      # end
      if has_column?(:last_updated_by)
        Issue.load_visible_last_updated_by(issues)
      end
      if has_column?(:relations)
        Issue.load_visible_relations(issues)
      end
      if has_column?(:last_notes)
        Issue.load_visible_last_notes(issues)
      end
      issues
    rescue ::ActiveRecord::StatementInvalid => e
      raise StatementInvalid.new(e.message)
    end

  end

end