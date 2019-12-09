require 'redmine'
require 'i18n'
require_relative 'lib/time_entry_patch'
require_relative 'lib/time_entry_custom_field_patch'
require_relative 'lib/view_custom_fields_form_listener'
require_relative 'lib/custom_fields_helper_patch'
require_relative 'lib/custom_field_patch'
require_relative 'lib/queries_helper_patch'
require_relative 'lib/time_entry_query_patch'
require_relative 'lib/query_patch'
require_relative 'lib/timelog_controller_patch'
require_relative 'lib/redmine/field_format_patch'
require_relative 'lib/redmine/helpers_timereport_patch'

# ActionDispatch::Callbacks.to_prepare do                for Rails 5.0 -- deprecated TODO sim need testing
# ActiveSupport::Reloader.to_prepare do                  for Rails 5.1
reloader = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Reloader

reloader.to_prepare do
  TimeEntry.send :include, TimeEntryPatch
  TimeEntryCustomField.send :include, TimeEntryCustomFieldPatch
  CustomFieldsHelper.send :include, CustomFieldsHelperPatch
  CustomField.send :include, CustomFieldPatch
  QueriesHelper.send :include, QueriesHelperPatch
  TimeEntryQuery.send :include, TimeEntryQueryPatch
  Query.send :include, QueryPatch
# class in query.rb file
  QueryCustomFieldColumn.send :include, QueryCustomFieldColumnPatch
  TimelogController.send :include, TimelogControllerPatch
  Redmine::FieldFormat::Base.send :include, RedmineFieldFormatPath
#  Redmine::Helpers::TimeReport.send :include, RedmineHelpersTimeReportPath
end

Redmine::Plugin.register :time_entry_custom_field_addons do
  name 'Time Entry Custom Field Addons plugin'
  author 'Sergey Melnikov'
  description 'This is a plugin for Redmine. Allow control the scope visibility timelog Custom field.'
  version '0.0.24'
  url 'https://github.com/SimSmolin/time_entry_custom_field_addons.git'
  author_url 'https://github.com/SimSmolin'

  # добавляем в блок полномочий ролей управления трудозатрат новую пермижн
  project_module :time_tracking do
    permission :edit_time_entries_on_behalf_of, {}, :require => :loggedin
    permission :edit_time_entries_advantage_time, {}, :require => :loggedin
    permission :view_time_entries_without_edit, {:timelog => [:edit]}, :require => :loggedin
  end

  settings :default => {'empty' => true}, :partial => 'settings/date_set'
  #Setting.plugin_time_entry_custom_field_addons[:notification_default]
end
