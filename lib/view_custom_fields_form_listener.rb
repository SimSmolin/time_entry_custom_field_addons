class ViewCustomFieldsFormListener < Redmine::Hook::ViewListener

  # добавляем в форму создания пользовательского тексторого поля подсказку какие поля будем "автоподстанавливать"
  def view_custom_fields_form_time_entry_custom_field(context = {})
    context[:hook_caller].send(:render, {:locals => context}.merge({:partial => "custom_fields_form_patch/form_patch"}))
  end

  def controller_time_entries_bulk_edit_before_save(context = {})
    # можно попробовать прямо в поля писать новые значения - вроде даже сохраняет
    # добавлено sim заполнение поля атрибутом
    #
    @project_context = context[:time_entry].issue.project # нужно для проверки закрытия периода
    context[:time_entry].editable_custom_field_values.each do |field|
      # if !valid_period_close?(field.customized.spent_on)
      if !TimeEntry.new.valid_period_close?(field.customized.spent_on)
        # новый вариант заполнения
        if field.custom_field.custom_action.present?
          if field.custom_field.custom_action.include? "$user"
            field.value=User.current.to_s
          end
          if field.custom_field.custom_action.include? "$spent_time"
            field.value=format_hours(context[:time_entry][:hours])
          end
          if field.custom_field.custom_action.include? "$time_now"
            field.value=Time.now.strftime("%d.%m.%Y %H:%M") + "(" +User.current.to_s+ ") " + field.value
          end
        end
      end
    end
  end
end

class ViewCustomFieldsListener < Redmine::Hook::Listener
  # если пришло поле с ID пользователя в параметрах, то подменяет атрибут user
  def controller_timelog_edit_before_save(context = {})
    # log.puts context[:time_entry].user.to_s + " = " + (User.find_by(:id => context[:params][:time_entry][:user_id])).to_s
    context[:time_entry].editable_custom_field_values.each do |field|
      if field.customized.editable_by_with_patch?(User.current)
        if field.custom_field.custom_action.present?
          if field.custom_field.custom_action.include? "$user"
            field.value=User.current.to_s
          end
          if (field.custom_field.custom_action.include? "$spent_time")
            if field.value.empty?
              field.value=format_hours(context[:time_entry][:hours])
            end
          end
          if field.custom_field.custom_action.include? "$time_now"
            field.value=Time.now.strftime("%d.%m.%Y %H:%M") + "(" +User.current.to_s+ ") " + field.value
          end
        end
      end
    end

    if context[:time_entry].user != User.find_by(:id => context[:params][:time_entry][:user_id]) &&
        context[:params][:time_entry][:user_id].present?
      context[:time_entry].user= User.find_by(:id => context[:params][:time_entry][:user_id])
      context[:time_entry].comments = User.current.name.to_s + ": " +
          context[:time_entry].comments.gsub(User.current.name.to_s + ": ", "")
    end
  end

end