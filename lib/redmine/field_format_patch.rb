module RedmineFieldFormatPath
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable
      field_attributes :participant_period_close

    end
  end

  module InstanceMethods

  end
end
