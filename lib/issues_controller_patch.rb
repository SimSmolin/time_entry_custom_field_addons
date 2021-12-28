require_dependency 'issues_controller'
require_relative '../app/helpers/issues_helper_add'

module IssuesControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.send(:include, IssuesHelperAdd)

    base.class_eval do
      unloadable
      alias_method :save_issue_with_child_records, :save_issue_with_child_records_with_patch
      alias_method :show, :show_with_patch
    end
  end

  module InstanceMethods

    def save_issue_with_child_records_with_patch
      Issue.transaction do
        params_time_entry = params[:time_entry]
        if !is_perm_bulk_insert_te_when_creating_issue ||
            (is_perm_bulk_insert_te_when_creating_issue && params_time_entry && params_time_entry[:hr_once_timeentry])
          if params_time_entry &&
                (params_time_entry[:hours].present? || params_time_entry[:comments].present?) &&
                User.current.allowed_to?(:log_time, @issue.project)
            time_entry = @time_entry || TimeEntry.new
            time_entry.project = @issue.project
            time_entry.issue = @issue
            time_entry.user = User.current
            time_entry.spent_on = User.current.today
            time_entry.safe_attributes = params[:time_entry]
            @issue.time_entries << time_entry
          end
        else
          if params_time_entry && params_time_entry[:hr_bulk_timeentry] &&
              @issue[:start_date].present? && @issue[:due_date].present? &&
              (@issue[:due_date] - @issue[:start_date]).to_i < 41 # не более 40 записей тркдозатрат за 1 р
            (@issue[:start_date] .. @issue[:due_date]).each do |date|
              time_entry = TimeEntry.new
              time_entry.project = @issue.project
              time_entry.issue = @issue
              time_entry.user_id = @issue[:assigned_to_id]
              time_entry.spent_on = date
              time_entry.safe_attributes = params[:time_entry]
              @issue.time_entries << time_entry
            end
          end
        end

        call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
        if @issue.save
          call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
        else
          raise ActiveRecord::Rollback
        end
      end
    end

    def show_with_patch
      @journals = @issue.visible_journals_with_index
      @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
      @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }

      if User.current.wants_comments_in_reverse_order?
        @journals.reverse!
        @changesets.reverse!
      end

      if User.current.allowed_to?(:view_time_entries, @project)
        Issue.load_visible_spent_hours([@issue])
        Issue.load_visible_total_spent_hours([@issue])
        Issue.load_visible_remaining_hours([@issue])
        Issue.load_visible_total_remaining_hours([@issue])
      end

      respond_to do |format|
        format.html {
          @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
          @priorities = IssuePriority.active
          @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
          @relation = IssueRelation.new
          retrieve_previous_and_next_issue_ids
          render :template => 'issues/show'
        }
        format.api
        format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
        format.pdf  {
          send_file_headers! :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf"
        }
      end
    end

  end
end