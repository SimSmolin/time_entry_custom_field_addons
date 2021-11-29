
module RolePatch
  def self.included(base) # :nodoc:

    base.const_set      :ISSUES_VISIBILITY_OPTIONS , [
      ['all', :label_issues_visibility_all],
      ['default', :label_issues_visibility_public],
      ['own', :label_issues_visibility_own],
      ['own_and_unassigned', :label_issues_visibility_own_and_unassigned]
    ]

    base.class_eval do
      unloadable
    end
  end

end