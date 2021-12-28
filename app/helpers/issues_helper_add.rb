module IssuesHelperAdd

    def is_perm_bulk_insert_te_when_creating_issue
        !@project.nil? && @project.users_by_role
                                  .map {|k,v|  v.include?(User.current)? k:nil}
                                  .compact
                                  .map {|role| role[:permissions]}
                                  .flatten
                                  .select{|permission| permission == :bulk_insert_timeenrty_when_creating_issue}
                                  .present?
    end

    def issue_remaining_hours_details(issue)
        if issue.total_remaining_hours > 0
            path = project_time_entries_path(issue.project, :issue_id => "~#{issue.id}")

            if issue.total_remaining_hours == issue.remaining_hours
                link_to(l_hours_short(issue.remaining_hours), path)
            else
                s = issue.remaining_hours > 0 ? l_hours_short(issue.remaining_hours) : ""
                s << " (#{l(:label_total)}: #{link_to l_hours_short(issue.total_remaining_hours), path})"
                s.html_safe
            end
        end
    end

end