# Database

The DB-backed specs create and drop a throwaway database on a server you name:

    export SEM_TEST_DB_URL=postgresql://postgres@localhost:<port>/postgres

or `SEM_TEST_SERVER_URL` (same, database name optional), or `CONF_DB_DEV_URL`, which
accepts the jdbc url `dev db session start --app platform` prints. Failing those,
`SEM_TEST_PGHOST` / `SEM_TEST_PGPORT` name the host and port (ci/build.sh uses these).
The role must be able to create databases and defaults to `postgres` when the url
names none. There is no default server; with none set, the DB-backed specs fail and say so.

# Run all specs:
./run.rb

This will also install rspec into ../gems directory

# Run a specific spec
rspec specs/library_spec.rb
rspec specs/library_spec.rb:12
