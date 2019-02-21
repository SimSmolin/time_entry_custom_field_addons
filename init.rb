require 'redmine'
require_relative 'lib/time_entry_patch'
require_relative 'lib/time_entry_custom_field_patch'

ActionDispatch::Callbacks.to_prepare do
  TimeEntry.send :include, TimeEntryPatch
end

ActionDispatch::Callbacks.to_prepare do
  TimeEntryCustomField.send :include, TimeEntryCustomFieldPatch
end


Redmine::Plugin.register :time_entry_custom_field_addons do
  name 'Time Entry Custom Field Addons plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end
