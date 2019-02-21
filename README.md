# Redmine TimeEntry(timelog) CustomField addons plugin 

This is Redmine plugin to add one feature. Allows you to choose visibility custom field in spent time form.

## Installing a plugin

1. 
   * Copy your plugin directory into #{RAILS_ROOT}/plugins (Redmine 3.x or 4.x) 
   * If you are downloading the plugin directly from GitHub, you can do so by changing into your plugin directory and issuing a command like 

    ```
    git clone https://github.com/SimSmolin/redmine_estimates.git
    ```

2. The plugin requires a migration, run the following command in #{RAILS_ROOT} to upgrade your database (make a db backup before).

   For Redmine 2.x and 3.x:
    
    ```
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    ```
   If you need uninstall previous version
   ```
    bundle exec rake redmine:plugins:migrate NAME=redmine_estimates VERSION=0 RAILS_ENV=production
   ```
   
   ####NOTE: 
   
    - the plugin has been tested on Redmine 2.1.x
    - the plugin has been tested on Redmine 3.x 

3. Restart Redmine

You should now be able to see the plugin list in Administration -> Plugins and configure the newly installed plugin.

Now you shold be able to add and manage issues estimates.

![issue_view](https://sc-cdn.scaleengine.net/i/a3c7276e23d226061c5eff4aaaca9ffb.png "Issue view")

Check out some permission for user's roles.

![issue_view](https://sc-cdn.scaleengine.net/i/154125d7a239cf41d9f8134b9c972bf4.png "User permissions")

View issues report with total estimates and total accepted estimates hours

![issue_view](https://sc-cdn.scaleengine.net/i/ee6dbc64144aed5f4e42d77ef38a6c44.png "Issue reports with estimates")
