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

        sum=0;
        TimeEntry.where(user_id: User.current, spent_on: Date.current-14..Date.current)
                 .each{|el| sum+=el.hours}

        dt_last_show_time = cf_last_show_time&.to_datetime rescue Time.at(0).to_datetime

        if ((cf_last_show_time.empty? || 15.minutes.ago > dt_last_show_time) &&
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
