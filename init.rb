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

# ActionDispatch::Callbacks.to_prepare do                for Rails 5.0 -- deprecated TODO sim need testing
# ActiveSupport::Reloader.to_prepare do                  for Rails 5.1
reloader = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Reloader

reloader.to_prepare do
  TimeEntry.send :include, TimeEntryPatch
end

reloader.to_prepare do
  TimeEntryCustomField.send :include, TimeEntryCustomFieldPatch
end

reloader.to_prepare do
  CustomFieldsHelper.send :include, CustomFieldsHelperPatch
end

reloader.to_prepare do
  CustomField.send :include, CustomFieldPatch
end

reloader.to_prepare do
  QueriesHelper.send :include, QueriesHelperPatch
end

reloader.to_prepare do
  TimeEntryQuery.send :include, TimeEntryQueryPatch
end

reloader.to_prepare do
  Query.send :include, QueryPatch
end

# class in query.rb file
reloader.to_prepare do
  QueryCustomFieldColumn.send :include, QueryCustomFieldColumnPatch
end

reloader.to_prepare do
  TimelogController.send :include, TimelogControllerPatch
end

Redmine::Plugin.register :time_entry_custom_field_addons do
  name 'Time Entry Custom Field Addons plugin'
  author 'Sergey Melnikov'
  description 'This is a plugin for Redmine. Allow control the scope visibility timelog Custom field.'
  version '0.0.11'
  url 'https://github.com/SimSmolin/time_entry_custom_field_addons.git'
  author_url 'https://github.com/SimSmolin'

  # добавляем в блок полномочий ролей управления трудозатрат новую пермижн
  project_module :time_tracking do
    permission :edit_time_entries_on_behalf_of, {}, :require => :loggedin
  end

end
