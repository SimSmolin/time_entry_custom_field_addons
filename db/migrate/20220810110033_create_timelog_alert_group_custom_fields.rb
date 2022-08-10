class CreateTimelogAlertGroupCustomFields < ActiveRecord::Migration
  def self.up
    c = CustomField.new(
      :name => 'group-alert-week-hours-rate',
      :editable => false,
      :visible => false,
      :description => 'Нормативное количество часов которые должен отработать сотрудник за неделю. Например 40.0. Используется для выдачи предупреждения о необходимости регулярного учета трудозатрат.',
      :field_format => 'float')
    c.type = 'GroupCustomField'
    c.save
    g = Group.new(
      :name => 'Сотрудники с нормой трудозатрат 40 часов в неделю'
    )
    g.custom_field_values.each do |cf|
      cf.value = 40.0 if cf.custom_field[:name] == "group-alert-week-hours-rate"
    end
    g.save
    g = Group.new(
      :name => 'Сотрудники с нормой трудозатрат 20 часов в неделю'
    )
    g.custom_field_values.each do |cf|
      cf.value = 20.0 if cf.custom_field[:name] == "group-alert-week-hours-rate"
    end
    g.save
  end

  def self.down
    Group.find_by_sql("select * from users where lastname = 'Сотрудники с нормой трудозатрат 40 часов в неделю'")[0].delete
    Group.find_by_sql("select * from users where lastname = 'Сотрудники с нормой трудозатрат 20 часов в неделю'")[0].delete
    CustomField.find_by_name('group-alert-week-hours-rate').delete
  end
end
