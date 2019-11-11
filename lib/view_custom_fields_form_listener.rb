class ViewCustomFieldsFormListener < Redmine::Hook::ViewListener

  # добавляем в форму создания пользовательского тексторого поля подсказку какие поля будем "автоподстанавливать"
  def view_custom_fields_form_time_entry_custom_field(context = {})
    # CustomField.where(type: :TimeEntryCustomField).update_all(visible: true)
    str=String::new(context[:hook_caller].output_buffer)
    context[:hook_caller].output_buffer=ActionView::OutputBuffer.new
    default_field_str = str.split(/<.?p>/).select{|m| m.include? "custom_field_default_value"}[0]
    # если формат поля текст то добавляем справочные поля после значения по умолчанию
    if context[:custom_field].field_format=="string"
    context[:hook_caller].output_buffer.safe_append = str.sub(default_field_str, default_field_str+
        content_tag(:em,"Автозаполнение:", class: "info")+
        content_tag(:em,"{:user} - Текущий пользователь,", class: "info")+
        content_tag(:em,"{:estimated_time} - Трудозатраты час(а,ов),", class: "info")+
        content_tag(:em,"{:time_now} - Текущее время", class: "info"))
    else
      context[:hook_caller].output_buffer.safe_append = str
    end
    # в этом месте должна быть вместо замены формы на дополнение при помощи call_hook
    context[:hook_caller].output_buffer.safe_append = context[:hook_caller].send(:render, {:locals => context}.merge({:partial => "custom_fields_form_patch/form_patch"}))
  end

  def controller_time_entries_bulk_edit_before_save(context = {})
    # можно попробовать прямо в поля писать новые значения - вроде даже сохраняет
    # добавлено sim заполнение поля атрибутом
    #
    context[:time_entry].editable_custom_field_values.each do |field|
      if !valid_period_close?(field.customized.spent_on)
        # если пустое то снова подставляем значение по умолчанию
        if (field.value.nil? || field.value.delete(" ").empty?)
          field.value=field.custom_field.default_value
        end
        field.value=field.value.gsub("{:user}", User.current.to_s)
        field.value=field.value.gsub("{:estimated_time}", format_hours(context[:time_entry][:hours])).gsub(".",",")
        field.value=field.value.gsub("{:time_now}", Time.now.strftime("%d.%m.%Y %H:%M"))
      end
    end
    # context[:custom_field] = context[:custom_field].to_s.gsub("{:user}", User.current.to_s)
    # custom_value.value = custom_value.to_s.gsub("{:estimated_time}", format_hours(@time_entry.hours))
    # custom_value.value = custom_value.to_s.gsub("{:time_now}", Time.now.strftime("%d.%m.%Y %H:%M"))
    #
  end

  def valid_period_close?(date_for_field)
    date_for_field = date_for_field || DateTime.parse('1970-01-01')
    shift = Setting.plugin_time_entry_custom_field_addons['period_close_date'].to_i > DateTime.now.day ? 1:0
    val_setting_months = Setting.plugin_time_entry_custom_field_addons['months_ago'].to_i + shift
    date_close = DateTime.now.beginning_of_month - val_setting_months.month
    date_for_field < date_close
  end


  # если пришло поле с ID пользователя в параметрах, то подменяет атрибут user
  def controller_timelog_edit_before_save(context = {})
    # log.puts context[:time_entry].user.to_s + " = " + (User.find_by(:id => context[:params][:time_entry][:user_id])).to_s
    if context[:time_entry].user != User.find_by(:id => context[:params][:time_entry][:user_id]) &&
        context[:params][:time_entry][:user_id].present?
      context[:time_entry].user= User.find_by(:id => context[:params][:time_entry][:user_id])
      context[:time_entry].comments = User.current.name.to_s + ": " +
          context[:time_entry].comments.gsub(User.current.name.to_s + ": ", "")
    end
  end

end