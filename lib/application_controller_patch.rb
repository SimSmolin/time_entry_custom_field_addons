require_dependency 'application_controller'

module ApplicationControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :deny_access, :deny_access_with_patch
    end
  end

  module InstanceMethods
    def deny_access_with_patch
      if params[:project_id] == 'krit' && params[:controller] == 'wiki' && params[:action] == 'show'
        redirect_to my_page_path
      else
        User.current.logged? ? render_403 : require_login
      end
    end
  end
end