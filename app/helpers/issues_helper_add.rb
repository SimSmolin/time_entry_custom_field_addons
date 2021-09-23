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

end