require_dependency 'queries_helper'

module QueriesHelperPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      alias_method :column_value, :column_value_with_patch # method "column_value" was modify
      alias_method :csv_content, :csv_content_with_patch # method "csv_content" was modify
    end
  end

  module InstanceMethods
    # Return custom field tag with its label tag
    def column_value_with_patch(column, item, value)
      # добавлено sim скрытие поля при отображении
      #
      if value.is_a?(CustomValue)
        value = if value.to_s.include?("{:user}") then value.to_s.gsub("{:user}", "") else value end
        value = if value.to_s.include?("{:estimated_time}") then value.to_s.gsub("{:estimated_time}", "") else value end
        value = if value.to_s.include?("{:time_now}") then value.to_s.gsub("{:time_now}", "") else value end
      #
      end
      case column.name
      when :id
        link_to value, issue_path(item)
      when :subject
        link_to value, issue_path(item)
      when :parent
        value ? (value.visible? ? link_to_issue(value, :subject => false) : "##{value.id}") : ''
      when :description
        item.description? ? content_tag('div', textilizable(item, :description), :class => "wiki") : ''
      when :last_notes
        item.last_notes.present? ? content_tag('div', textilizable(item, :last_notes), :class => "wiki") : ''
      when :done_ratio
        progress_bar(value)
      when :relations
        content_tag('span',
                    value.to_s(item) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
                    :class => value.css_classes_for(item))
      when :hours, :estimated_hours
        format_hours(value)
      when :spent_hours
        link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "#{item.id}"))
      when :total_spent_hours
        link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "~#{item.id}"))
      when :attachments
        value.to_a.map {|a| format_object(a)}.join(" ").html_safe
      else
        format_object(value)
      end
    end

    def csv_content_with_patch(column, item)
      value = column.value_object(item)
      if value.is_a?(Array)
        value.collect {|v|

          csv_value(column, item, v)
        }.compact.join(', ')
      else
        # value = value
        csv_value(column, item, value).to_s.gsub("{:user}", "").gsub("{:estimated_time}", "").gsub("{:time_now}", "")
      end
    end

  end
end