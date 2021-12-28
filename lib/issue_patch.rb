require_dependency 'issue'

module IssuePatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :visible?, :visible_with_patch?
    end

    base.instance_eval do
      def visible_condition(user, options={})
        Project.allowed_to_condition(user, :view_issues, options) do |role, user|
          sql = if user.id && user.logged?
                  case role.issues_visibility
                  when 'all'
                    '1=1'
                  when 'default'
                    user_ids = [user.id] + user.groups.map(&:id).compact
                    "(#{table_name}.is_private = #{connection.quoted_false} OR #{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
                  when 'own'
                    user_ids = [user.id] + user.groups.map(&:id).compact
                    "(#{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
                  when 'own_and_unassigned'
                    user_ids = [user.id] + user.groups.map(&:id).compact
                    "(#{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}) OR #{table_name}.assigned_to_id is NULL)"
                  else
                    '1=0'
                  end
                else
                  "(#{table_name}.is_private = #{connection.quoted_false})"
                end
          unless role.permissions_all_trackers?(:view_issues)
            tracker_ids = role.permissions_tracker_ids(:view_issues)
            if tracker_ids.any?
              sql = "(#{sql} AND #{table_name}.tracker_id IN (#{tracker_ids.join(',')}))"
            else
              sql = '1=0'
            end
          end
          sql
        end
      end


      # Preloads visible remaining time for a collection of issues
      def self.load_visible_remaining_hours(issues, user=User.current)
        if issues.any?
          remaining_hours_by_issue_id = TimeEntry.visible(user).where(:issue_id => issues.map(&:id)).group(:issue_id).sum(:hours)
          issues.each do |issue|
            estimated_hours = issue.estimated_hours ? issue.estimated_hours : 0.0
            issue.instance_variable_set "@remaining_hours", (estimated_hours - (remaining_hours_by_issue_id[issue.id] || 0.0))
          end
        end
      end

      # Preloads visible total remaining time for a collection of issues
      def self.load_visible_total_remaining_hours(issues, user=User.current)
        if issues.any?
          remaining_hours_by_issue_id = TimeEntry.visible(user).joins(:issue).
            joins("JOIN #{Issue.table_name} parent ON parent.root_id = #{Issue.table_name}.root_id" +
                    " AND parent.lft <= #{Issue.table_name}.lft AND parent.rgt >= #{Issue.table_name}.rgt").
            where("parent.id IN (?)", issues.map(&:id)).group("parent.id").sum(:hours)
          estimated_hours_by_issue_id = Issue.visible(user).
            joins("JOIN #{Issue.table_name} parent ON parent.root_id = #{Issue.table_name}.root_id" +
                    " AND parent.lft <= #{Issue.table_name}.lft AND parent.rgt >= #{Issue.table_name}.rgt").
            where("parent.id IN (?)", issues.map(&:id)).group("parent.id").sum(:estimated_hours)
          issues.each do |issue|
            issue.instance_variable_set "@total_remaining_hours",  (estimated_hours_by_issue_id[issue.id] - (remaining_hours_by_issue_id[issue.id] || 0.0))
          end
        end
      end
    end

  end

  module InstanceMethods
    def visible_with_patch?(usr=nil)
      (usr || User.current).allowed_to?(:view_issues, self.project) do |role, user|
        visible = if user.logged?
                    case role.issues_visibility
                    when 'all'
                      true
                    when 'default'
                      !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
                    when 'own'
                      self.author == user || user.is_or_belongs_to?(assigned_to)
                    when 'own_and_unassigned'
                      self.author == user || user.is_or_belongs_to?(assigned_to)
                    else
                      false
                    end
                  else
                    !self.is_private?
                  end
        unless role.permissions_all_trackers?(:view_issues)
          visible &&= role.permissions_tracker_ids?(:view_issues, tracker_id)
        end
        visible
      end
    end

    def remaining_hours
      @remaining_hours
    end

    def total_remaining_hours
      @total_remaining_hours
    end

  end
end