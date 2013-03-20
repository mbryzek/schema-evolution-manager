Documents Gilt Groupe conventions for schema:

  * Use bigint and bigserial everywhere, in place of int/bigint
    (e.g. we prefer longs for all Id columns)

  * When creating constraints, name them according to:

     - primary key: Do not name. Postgresql will generate a good name
       automatically.

     - not null: Do not name. Constraint name is never needed in table
       administration.

     - otherwise, names should follow <table_name>_<column_name>_<suffix> where suffix is:

        check: ck
        unique: un
        foreign key: fk

  * If you are creating a column that will store a guid, make sure its
    datatype is UUID. This will give you automated validation of the
    format of the UUID and it is stored internally more efficiently.
    See http://www.postgresql.org/docs/9.2/static/datatype-uuid.html

  * Table and column names should follow rails naming conventions. Briefly:

      - table names should be plural - users and not user
      - every table should have a primary key named 'id'
      - A foreign key to another table should follow convention from
        rails, e.g. 'user_id' column implies that it references a
        table called 'users' with primary key 'id'

  * Use the provided plsql API (see scripts/20130318-105456.sql) to
    add audit columns for tracking created_at, created_by_guid, updated_at,
    updated_by_guid, deleted_by, deleted_by_guid. The big benefit is data will
    never immediately be removed - instead everything will be 'soft-deleted'.
    Keep this in mind when creating unique indexes (example below).

  * Every new table should contain all these columns. Primary benefit
    is making it simpler to see who changed what when (in basic cases)
    and to support data replication

  * Every table must have a comment explaining its purpose. We also encourage
    adding column level comments where not immediately obvious from the
    column name. A good test here for what is obvious is whether or not the
    comment actually adds any information - if the column comment itself is
    useless, better to just not create.

Example:

  create table sites (
    id             bigserial primary key
  );

  select schema_evolution_manager.create_basic_audit_data('public', 'sites');
  create unique index examples_lower_email_address_not_deleted_un on examples(lower(email_address)) where deleted_at is null;

  comment on table sites is '
    A site is a general concept that ...
  ';

  create table examples (
    id             bigserial primary key,
    email_address  varchar(300) not null,
    site_id        bigint not null constraint examples_site_id_fk references sites(id)
  );

  select schema_evolution_manager.create_basic_audit_data('public', 'examples');
  create unique index examples_lower_email_address_not_deleted_un on examples(lower(email_address)) where deleted_at is null;

  comment on table examples is '
    Stores information on all of our registered examples.
  ';

\d examples -- to see columns that are actually created.
