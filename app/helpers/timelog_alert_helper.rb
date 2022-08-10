module TimelogAlertHelper
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      define_method :send_timelog_alert?, instance_method(:send_timelog_alert?)
    end
  end

  module InstanceMethods
    def send_timelog_alert?
      if (CustomField.find_by_name("timelog-alert-last-alert") &&
          CustomField.find_by_name("timelog-alert-week-hours-rate"))
        cf_last_show_time_id =  CustomField.find_by_name("timelog-alert-last-alert").id
        cf_last_show_time = User.current.custom_value_for(cf_last_show_time_id).to_s

        cf_week_hours_rate_id =  CustomField.find_by_name("timelog-alert-week-hours-rate").id
        cf_week_hours_rate = User.current.custom_value_for(cf_week_hours_rate_id).to_s.to_f

        cf_group_week_hours_rate = 0
        User.current.groups.each do |group|
          value = 0
          group.custom_field_values.each do |cf|
            value = cf.custom_field[:name] == "group-alert-week-hours-rate"? cf.value.to_f : 0
          end
          cf_group_week_hours_rate = value if (value > cf_group_week_hours_rate)
        end

        cf_week_hours_rate = cf_group_week_hours_rate if cf_week_hours_rate == 0.0

        sum=0;
        TimeEntry.where(user_id: User.current, spent_on: Date.current-14..Date.current)
                 .each{|el| sum+=el.hours}

        dt_last_show_time = cf_last_show_time&.to_datetime rescue Time.at(0).to_datetime

        timeentry_alert_timeout = Setting.plugin_time_entry_custom_field_addons['timeentry_alert_timeout'].to_i
        timeentry_alert_timeout = 15 if timeentry_alert_timeout < 1
        if ((cf_last_show_time.empty? || timeentry_alert_timeout.minutes.ago > dt_last_show_time) &&
          sum < cf_week_hours_rate * 2 * 0.9)
          User.current.custom_field_values= {cf_last_show_time_id => DateTime.current.to_s}
          User.current.save_custom_field_values
          return true
        end

      end
      false
    end
  end
end
