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
  end
end