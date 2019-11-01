resources :projects do
  # as issue
  get 'time_entries/:copy_from/copy', :to => 'timelog#new', :as => 'copy_time_entries'
end
resources :time_entries, :controller => 'timelog', :except => :destroy do
  member do
    # Used when viewing the time_entry form of an existing time entry without editing
    get 'only_view', :to => 'timelog#edit'
  end
end