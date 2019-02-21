# Redmine TimeEntry(timelog) CustomField addons plugin 

This is Redmine plugin to add one feature. Allows you to choose visibility custom field in spent time form.

## Installing a plugin

1. 
   * Copy your plugin directory into #{RAILS_ROOT}/plugins (Redmine 3.x or 4.x) 
   * If you are downloading the plugin directly from GitHub, you can do so by changing into your plugin directory and issuing a command like 

    ```
    https://github.com/SimSmolin/time_entry_custom_field_addons.git
    ```
    For uninstall simple delete directory ```time_entry_custom_field_addons``` into #{RAILS_ROOT}/plugins 

    ####NOTE: 
   
        - the plugin has been tested on Redmine 3.4.4 - 3.4.8
        - the plugin has been tested on Redmine 4.0.1 

2. Restart Redmine

You should now be able to see the plugin list in Administration -> Plugins and configure the newly installed plugin.

Now you shold be able to add and manage new Custom field / Spent time.
For a new field you can specify the scope visibility for Role and Project 

![screen](https://github.com/SimSmolin/MyPrintScreen/raw/master/screen.jpg "Screen")



