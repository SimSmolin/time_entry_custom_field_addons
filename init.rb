require 'redmine'
require 'i18n'
require 'role'

#
require_relative 'app/helpers/custom_fields_helper_add'
require_relative 'app/helpers/issues_helper_add'
require_relative 'app/helpers/timelog_alert_helper'

require_relative 'lib/time_entry_patch'
require_relative 'lib/time_entry_custom_field_patch'
require_relative 'lib/view_custom_fields_form_listener'
require_relative 'lib/custom_field_patch'
require_relative 'lib/custom_fields_helper_patch'
require_relative 'lib/time_entry_query_patch'
require_relative 'lib/query_patch'
require_relative 'lib/user_patch'
require_relative 'lib/timelog_controller_patch'
require_relative 'lib/issues_controller_patch'
require_relative 'lib/redmine/field_format_patch'
require_relative 'lib/redmine/helpers_timereport_patch'
require_relative 'lib/role_patch'

# ActionDispatch::Callbacks.to_prepare do                for Rails 5.0 -- deprecated TODO sim need testing
# ActiveSupport::Reloader.to_prepare do                  for Rails 5.1
reloader = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Reloader

reloader.to_prepare do
  ApplicationController.send :include,ApplicationControllerPatch
  CustomField.send :include, CustomFieldPatch
  CustomFieldsHelper.send :include, CustomFieldsHelperPatch
  IssuesController.send :include, IssuesControllerPatch
  Query.send :include, QueryPatch
  TimeEntryCustomField.send :include, TimeEntryCustomFieldPatch
  TimeEntry.send :include, TimeEntryPatch
  TimeEntryQuery.send :include, TimeEntryQueryPatch
  TimelogController.send :include, TimelogControllerPatch
  Redmine::FieldFormat::Base.send :include, RedmineFieldFormatPath
  QueryCustomFieldColumn.send :include, QueryCustomFieldColumnPatch
  Role.send :include, RolePatch
  User.send :include, UserPatch
  Issue.send :include, IssuePatch
  IssueQuery.send :include, IssueQueryPatch
  #  Redmine::Helpers::TimeReport.send :include, RedmineHelpersTimeReportPath
  ApplicationHelper.send(:include, TimelogAlertHelper)
end

Redmine::Plugin.register :time_entry_custom_field_addons do
  name 'Time Entry Custom Field Addons plugin'
  author 'Sergey Melnikov'
  description 'This is a plugin for Redmine. Allow control the scope visibility timelog Custom field.'
  version '0.2.16'
  url 'https://github.com/SimSmolin/time_entry_custom_field_addons.git'
  author_url 'https://github.com/SimSmolin'

  # bundle exec rake redmine:plugins:migrate RAILS_ENV=production

  # добавляем в блок полномочий ролей управления трудозатрат новую пермижн
  project_module :time_tracking do
    permission :edit_time_entries_on_behalf_of, {}, :require => :loggedin
    permission :edit_time_entries_advantage_time, {}, :require => :loggedin
    permission :view_time_entries_without_edit, {:timelog => [:edit]}, :require => :loggedin
  end

  project_module :issue_tracking do
    permission :bulk_insert_timeenrty_when_creating_issue, {}, :require => :loggedin
  end

  Rails.configuration.to_prepare do
    UsersController.send(:helper, CustomFieldsHelperAdd)
    TimelogController.send(:helper, CustomFieldsHelperAdd)
    IssuesController.send(:helper, CustomFieldsHelperAdd)
    IssuesController.send(:helper, IssuesHelperAdd)
  end

  settings :default => {'empty' => true}, :partial => 'settings/date_set'
  #Setting.plugin_time_entry_custom_field_addons[:notification_default]

  require 'dispatcher' unless Rails::VERSION::MAJOR >= 3
  if Rails::VERSION::MAJOR >= 3
    ActionDispatch::Callbacks.to_prepare do
      require_dependency 'redmine_time_entry_alert/hooks'
    end
  else
    Dispatcher.to_prepare :time_entry_custom_field_addons do
      require_dependency 'redmine_time_entry_alert/hooks'
    end
  end

end
