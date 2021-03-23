To add a new database migration script:

  1. Make sure you have head of main:
     git checkout main
     git fetch
     git rebase origin/main

  2. Create a local branch for your change
     git checkout -b tmp

  3. Create a file containing your upgrade script - e.g. new.sql

  4. Add your upgrade script
     %%add_script_path%% ./new.sql
     git commit -m 'Add upgrade script to ...' scripts

  5. Push change

To upgrade your local postgresql database:

  sem-apply --host localhost --name sample --user postgres

or use the wrapper script:

  ./dev.rb

For more information on the schema evolution manager tools, look at
schema-evolution-manager/README.md
