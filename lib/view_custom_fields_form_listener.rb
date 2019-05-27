class ViewCustomFieldsFormListener < Redmine::Hook::ViewListener

  def view_custom_fields_form_time_entry_custom_field(context = {})
    buf=context[:hook_caller].output_buffer
    context[:hook_caller].output_buffer=ActionView::OutputBuffer.new
    str=String::new(buf)
    default_field_str = str.split(/<.?p>/).select{|m| m.include? "custom_field_default_value"}[0]
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
    context[:time_entry].custom_field_values.each do |value|
      value.value=value.value.gsub("{:user}", User.current.to_s)
      value.value=value.value.gsub("{:estimated_time}", format_hours(context[:time_entry][:hours]))
      value.value=value.value.gsub("{:time_now}", Time.now.strftime("%d.%m.%Y %H:%M"))
    end
    # context[:custom_field] = context[:custom_field].to_s.gsub("{:user}", User.current.to_s)
    # custom_value.value = custom_value.to_s.gsub("{:estimated_time}", format_hours(@time_entry.hours))
    # custom_value.value = custom_value.to_s.gsub("{:time_now}", Time.now.strftime("%d.%m.%Y %H:%M"))
    #

  end
end