require_dependency 'query'

module QueryPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :add_custom_fields_filters, :add_custom_fields_filters_with_patch # method "add_custom_fields_filters" was modify
      alias_method :validate_query_filters, :validate_query_filters_with_patch
      alias_method :sql_for_field, :sql_for_field_with_patch
      define_method :role_values, instance_method(:role_values)
      define_method :projects_by_role_values, instance_method(:projects_by_role_values)
    end

    base.operators[:chm] = :label_current_halfmonth
    base.operators[:phm] = :label_previous_halfmonth
    base.operators[:llm] = :label_prev_last_month

    base.operators_by_filter_type[:tree] = ["=", "!", "~", "!*", "*"]
    base.operators_by_filter_type[:date] = [ "=", ">=", "<=", "><", "<t+", ">t+", "><t+", "t+", "t", "ld", "w", "lw", "l2w", "chm", "phm", "m", "lm", "llm", "y", ">t-", "<t-", "><t-", "t-", "!*", "*" ]
    base.operators_by_filter_type[:date_past] = [ "=", ">=", "<=", "><", ">t-", "<t-", "><t-", "t-", "t", "ld", "w", "lw", "l2w", "chm", "phm", "m", "lm", "llm", "y", "!*", "*" ]

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

    def validate_query_filters_with_patch
      filters.each_key do |field|
        if values_for(field)
          case type_for(field)
          when :integer
            add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/\A[+-]?\d+(,[+-]?\d+)*\z/) }
          when :float
            add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/\A[+-]?\d+(\.\d*)?\z/) }
          when :date, :date_past
            case operator_for(field)
            when "=", ">=", "<=", "><"
              add_filter_error(field, :invalid) if values_for(field).detect {|v|
                v.present? && (!v.match(/\A\d{4}-\d{2}-\d{2}(T\d{2}((:)?\d{2}){0,2}(Z|\d{2}:?\d{2})?)?\z/) || parse_date(v).nil?)
              }
            when ">t-", "<t-", "t-", ">t+", "<t+", "t+", "><t+", "><t-"
              add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
            end
          end
        end

        add_filter_error(field, :blank) unless
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.blank?) or
            # filter doesn't require any value
            ["o", "c", "!*", "*", "t", "ld", "w", "lw", "l2w", "chm", "phm", "m", "lm", "llm", "y", "*o", "!o"].include? operator_for(field)
      end if filters
    end

    def sql_for_field_with_patch(field, operator, value, db_table, db_field, is_custom_filter=false)
      sql = ''
      case operator
      when "="
        if value.any?
          case type_for(field)
          when :date, :date_past
            sql = date_clause(db_table, db_field, parse_date(value.first), parse_date(value.first), is_custom_filter)
          when :integer
            int_values = value.first.to_s.scan(/[+-]?\d+/).map(&:to_i).join(",")
            if int_values.present?
              if is_custom_filter
                sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) IN (#{int_values}))"
              else
                sql = "#{db_table}.#{db_field} IN (#{int_values})"
              end
            else
              sql = "1=0"
            end
          when :float
            if is_custom_filter
              sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5})"
            else
              sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
            end
          else
            sql = queried_class.send(:sanitize_sql_for_conditions, ["#{db_table}.#{db_field} IN (?)", value])
          end
        else
          # IN an empty set
          sql = "1=0"
        end
      when "!"
        if value.any?
          sql = queried_class.send(:sanitize_sql_for_conditions, ["(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (?))", value])
        else
          # NOT IN an empty set
          sql = "1=1"
        end
      when "!*"
        sql = "#{db_table}.#{db_field} IS NULL"
        sql << " OR #{db_table}.#{db_field} = ''" if (is_custom_filter || [:text, :string].include?(type_for(field)))
      when "*"
        sql = "#{db_table}.#{db_field} IS NOT NULL"
        sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
      when ">="
        if [:date, :date_past].include?(type_for(field))
          sql = date_clause(db_table, db_field, parse_date(value.first), nil, is_custom_filter)
        else
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) >= #{value.first.to_f})"
          else
            sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
          end
        end
      when "<="
        if [:date, :date_past].include?(type_for(field))
          sql = date_clause(db_table, db_field, nil, parse_date(value.first), is_custom_filter)
        else
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) <= #{value.first.to_f})"
          else
            sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
          end
        end
      when "><"
        if [:date, :date_past].include?(type_for(field))
          sql = date_clause(db_table, db_field, parse_date(value[0]), parse_date(value[1]), is_custom_filter)
        else
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f})"
          else
            sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
          end
        end
      when "o"
        sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_false})" if field == "status_id"
      when "c"
        sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_true})" if field == "status_id"
      when "><t-"
        # between today - n days and today
        sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0, is_custom_filter)
      when ">t-"
        # >= today - n days
        sql = relative_date_clause(db_table, db_field, - value.first.to_i, nil, is_custom_filter)
      when "<t-"
        # <= today - n days
        sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i, is_custom_filter)
      when "t-"
        # = n days in past
        sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i, is_custom_filter)
      when "><t+"
        # between today and today + n days
        sql = relative_date_clause(db_table, db_field, 0, value.first.to_i, is_custom_filter)
      when ">t+"
        # >= today + n days
        sql = relative_date_clause(db_table, db_field, value.first.to_i, nil, is_custom_filter)
      when "<t+"
        # <= today + n days
        sql = relative_date_clause(db_table, db_field, nil, value.first.to_i, is_custom_filter)
      when "t+"
        # = today + n days
        sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i, is_custom_filter)
      when "t"
        # = today
        sql = relative_date_clause(db_table, db_field, 0, 0, is_custom_filter)
      when "ld"
        # = yesterday
        sql = relative_date_clause(db_table, db_field, -1, -1, is_custom_filter)
      when "w"
        # = this week
        first_day_of_week = l(:general_first_day_of_week).to_i
        day_of_week = User.current.today.cwday
        days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
        sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6, is_custom_filter)
      when "lw"
        # = last week
        first_day_of_week = l(:general_first_day_of_week).to_i
        day_of_week = User.current.today.cwday
        days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
        sql = relative_date_clause(db_table, db_field, - days_ago - 7, - days_ago - 1, is_custom_filter)
      when "l2w"
        # = last 2 weeks
        first_day_of_week = l(:general_first_day_of_week).to_i
        day_of_week = User.current.today.cwday
        days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
        sql = relative_date_clause(db_table, db_field, - days_ago - 14, - days_ago - 1, is_custom_filter)
      when "m"
        # = this month
        date = User.current.today
        sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month, is_custom_filter)
      when "lm"
        # = last month
        date = User.current.today.prev_month
        sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month, is_custom_filter)
      when "llm"
        # = last last month
        date = User.current.today.prev_month.prev_month
        sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month, is_custom_filter)
      when "chm"
        # = current half month
        today = User.current.today
        begin_date = today.day > 15 ? today.beginning_of_month.next_day(15) : today.beginning_of_month
        end_date = today.day > 15 ? today.end_of_month : today.beginning_of_month.next_day(14)
        sql = date_clause(db_table, db_field, begin_date, end_date, is_custom_filter)
      when "phm"
        # = previous half month
        today = User.current.today
        begin_date = today.day > 15 ? today.beginning_of_month : today.prev_month.beginning_of_month.next_day(15)
        end_date = today.day > 15 ? today.beginning_of_month.next_day(14) : today.prev_month.end_of_month
        sql = date_clause(db_table, db_field, begin_date, end_date, is_custom_filter)
      when "y"
        # = this year
        date = User.current.today
        sql = date_clause(db_table, db_field, date.beginning_of_year, date.end_of_year, is_custom_filter)
      when "~"
        sql = sql_contains("#{db_table}.#{db_field}", value.first)
      when "!~"
        sql = sql_contains("#{db_table}.#{db_field}", value.first, false)
      else
        raise "Unknown query operator #{operator}"
      end

      return sql
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