resources :projects do
  # as issue
  get 'time_entries/:copy_from/copy', :to => 'timelog#new', :as => 'copy_time_entries'
end