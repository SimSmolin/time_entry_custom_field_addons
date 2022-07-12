class TimelogAlertUserCustomField < ActiveRecord::Migration
  def self.up
    c = CustomField.new(
      :name => 'timelog-alert-week-hours-rate',
      :editable => false,
      :visible => false,
      :field_format => 'float')
    c.type = 'UserCustomField'
    c.save
    d = CustomField.new(
      :name => 'timelog-alert-last-alert',
      :editable => false,
      :visible => false,
      :field_format => 'string')
    d.type = 'UserCustomField'
    d.save
  end

  def self.down
    CustomField.find_by_name('timelog-alert-week-hours-rate').delete
    CustomField.find_by_name('timelog-alert-last-alert').delete
  end
end