# Schema Evolution Manager (sem)

## Intended Audience

- Engineers who regularly manage the creation of scripts to update the schema in a postgresql database.

- Engineers who want to simplify and/or standardize how other team members contribute schema changes to a postgresql database.

## Purpose

Schema Evolution Manager (sem) makes it very simple for engineers to
contribute schema changes to a postgresql database, managing the
schema evolutions as proper source code. Schema changes are deployed
as gzipped tarballs named with the corresponding git tag.

To apply schema changes to a particular database, download a tarball
and use sem to figure out which scripts have not yet been
applied, then apply those scripts in chronological order.

sem provides well tested, simple tools to manage the process
of creating and applying schema upgrade scripts to databases in all
environments.

 - scripts are automatically named with a timestamp assigned at time
   of creation

 - all scripts applied to the postgresql database are recorded in
   the table schema_evolution_manager.scripts - making it simple to
   see what has been applied if needed.

sem contains only tools for managing schema evolutions. The
basic idea is that you create one git repository for each of your
databases then use sem to manage the schema evolution of
each database.

At Gilt Groupe, we have used sem since early 2012 and have
observed an increase in the reliability of our production schema
deploys across dozens of independent postgresql databases.

See INSTALLATION and GETTING STARTED for details.


## Project Goals

  - Absolutely minimal set of dependencies. We found that anything
    more complex led developers to prefer to manage their own schema
    evolutions. We prefer small sets of scripts that each do one thing
    well.

  - Committed to true simplicity - features that would add complexity
    are not added. We hope that more advanced features might be built
    on top of schema evolution manager.

  - Works for ALL applications - schema management is a first class
    task now so any application framework can leverage these
    migration tools.

  - No rollback. We have found in practice that rolling back schema
    changes is not 100% reliable. Therefore we inentionally do NOT
    support rollback. This is an often debated element of sem,
    and although the design itself could be easily extended to support
    rollback, we currently have no plans to do so.

In place of rollback, we prefer to keep focus on the criticalness of
schema changes, encouraging peer review and lots of smaller evolutions
that themselves are relatively harmless.

This stems from the idea that we believe schema evolutions are
fundamentally risky. We believe the best way to manage this risk is
to:

  1. Treat schema evolution changes as normal software releases
     as much as possible

  2. Manage schema versions as simple tarballs - artifacts are really
     important because they provide 100% reproducibility.  This means
     the exact same artifacts can be applied in development then QA
     and finally production environments.

  3. Isolate schema changes as their own deploy. This then
     guarantees that every other application itself can be rolled
     back if needed. In practice, we have seen greater risk when
     applications couple code changes with schema changes.

This last point bears some more detail. By fundamentally deciding to
manage and release schema changes independent of application changes:

  1. Schema changes are required to be incremental. For example, to
     rename a column takes 4 separate, independent production deploys:

    a. add new column
    b. deploy changes in application to use old and new column
    c. remove old column
    d. deploy changes in application to use only new column

  Though at first this may seem more complex, each individual change itself is smaller and lower risk.

  2. It is worth repeating that all application deploys can now be rolled back. This has been a huge win for our teams.


## Talks

First presented at PGDay NYC 2013: https://speakerdeck.com/mbryzek/schema-evolutions-at-gilt-groupe

## Dependencies

- Ruby: Most testing against 1.8.7; 1.9.x and 2.0.0 are supported and
  should work

- Postgres: Only tested against 9.x. We minimize use of advanced
  features and should work against 8.x series. If you try 8.x and
  run into problems, please let us know so we can update.

- plpgsql must be available in the database. If needed you can:

    createlang plpgsql template1
    [http://www.postgresql.org/docs/8.4/static/app-createlang.html]

- Git: Designed to use git for history. Most testing against git 1.7
  and git 1.8.  At Gilt Groupe, we additionally use Gerrit Code Review
  [https://code.google.com/p/gerrit/] to have a very nice workflow for
  code review of all schema changes.


## Installation

    git clone git://github.com/gilt/schema-evolution-manager.git
    cd schema-evolution-manager
    git checkout 0.9.11
    ruby ./configure.rb
    sudo ./install.rb


## Getting Started

### Initialization

    git init /tmp/sample
    sem-init --dir /tmp/sample --name sample_development --user postgres

### Writing your first sql script

    cd /tmp/sample
    echo "create table tmp_table (id integer)" > new.sql
    sem-add ./new.sql

### Applying changes to your local database:

    cd /tmp/sample
    createdb sample_development
    sem-apply --host localhost --name sample_development --user postgres

### When you are happy with your change, commit:

    git commit -m "Adding a new tmp table to test sem process" scripts

## Publishing a Release

    cd /tmp/sample
    sem-dist

If you already have a tag:

    sem-dist --tag 0.0.2

You will now have a single artifict -
/tmp/sample/dist/sample-0.0.2.tar.gz - that you can manage in standard
deploy process. At Gilt Groupe, we upload these artifacts to nexus and
then deploy in production by downloading from nexus. scp/rsync work
fine as well.


## Deploying Schema Changes

### Extract tarball on server

    scp /tmp/sample/dist/sample-0.0.2.tar.gz <your server>:~/
    ssh <your server>
    tar xfz sample-0.0.2.tar.gz
    cd sample-0.0.2

### Do a dry run

    sem-apply --host localhost --name sample_production --user postgres --dry_run

You will likely see a number of create table statements (see data model section below). You should also see:

      [DRY RUN] Applying 20130318-214407.sql

which tells you that if you apply these changes, that sql script will be applied to the sample_production db


### Apply the changes

    sem-apply --host localhost --name sample_production --user postgres

You will see:

      Upgrading schema for postgres@localhost/sample_production
      Applying 20130318-214407.sql

Attempt to apply again:

    sem-apply --host localhost --name sample_production --user postgres

You will see:

      Upgrading schema for postgres@localhost/sample_production
        All scripts have been previously applied


## Data Model

sem will create a new postgresql schema in your database named 'schema_evolution_manager'

    psql sample_development
    set search_path to schema_evolution_manager;
    \dt

        Schema    |       Name        | Type  |  Owner
     -------------+-------------------+-------+----------
     schema_evolution_manager | bootstrap_scripts | table | postgres
     schema_evolution_manager | scripts           | table | postgres

Each of these tables has a column named 'filename' which keeps track
of the sql files applied to each database.

- The scripts table is used for your application.
- The bootstrap_scripts table is used to manage upgrades to the sem application itself.

For details on these tables, see scripts/*sql where the tables themselves are defined.


## PLPGSQL Utilities

We've included a copy of the schema conventions we practice at Gilt
Groupe [CONVENTIONS.md]. There are also a number of utility plpgsql functions to help
developers apply these conventions in a systematic way.

The helpers are defined in

  scripts/20130318-105456.sql

We have found these utilities incredibly useful - and are committed to
providing only the most relevant, high quality, and extremely clear
helpers as possible.

In CONVENTIONS.md you will find a simple example of these conventions
and utilities in practice.


## Command Line Utilities

- sem-init: Initialize a git repository for sem support
- sem-add: Adds a database upgrade script
- sem-dist: Create a distribution tar.gz file containing schema upgrade scripts
- sem-apply: Apply any deltas from a distribution tarball to a particular database


## TODO

- Consider offering an option to install via ruby gems


## License

Copyright 2013 Gilt Groupe, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
