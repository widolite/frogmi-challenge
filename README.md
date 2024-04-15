## Bootstrapping the Project

This guide outlines the steps to set up an init the project.

**Prerequisites:**

* Ruby (Recommended version: https://www.ruby-lang.org/)
* RubyGems (Package manager for Ruby: Installed with Ruby)
* Text editor or IDE of your choice
* Git - 

**Steps:**

1. **Clone using the web URL:**

   ```bash
   git clone https://github.com/widolite/frogmi-challenge.git
   cd frogmi-challenge

2. **Install the gems:**

   ```bash
   bubdle install

3. **Bootstrap the database with the .sql file**

   ```bash
   # by default use postgres
   psql -U postgres -W -h localhost < features.sql

4. **Init the ruby project**

   ```bash
   ruby features_app.rb