module TimelogControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :new, :new_patch # method "new" was modify
    end
  end

  module InstanceMethods
    def new_patch
      @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
      @time_entry.copy_from(params[:copy_from]) unless params[:copy_from].nil?
      @time_entry.safe_attributes = params[:time_entry]
    end
  end

end