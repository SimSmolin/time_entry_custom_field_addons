class ViewCustomFieldsFormListener < Redmine::Hook::ViewListener

  def view_custom_fields_form_time_entry_custom_field(context = {})
    buf=context[:hook_caller].output_buffer
    context[:hook_caller].output_buffer=ActionView::OutputBuffer.new
    str=String::new(buf)
    default_field_str = str.split(/<.?p>/).select{|m| m.include? "custom_field_default_value"}[0]
    context[:hook_caller].output_buffer.safe_append = str.sub(default_field_str, default_field_str+
      ' <em class="info">Автозаполнение: <br>
        {:user} - Текущий пользователь,<br>
        {:estimated_time} - Трудозатраты час(а,ов),<br>
        {:time_now} - Текущее время </em>')
    # context[:hook_caller].output_buffer.safe_append = context[:hook_caller].send(:render, {:locals => context}.merge({:partial => "user_custom_fields_extention/view_custom_field_form"}))
  end
end