-- Records the released repository version applied to this database. The latest
-- row (max id) is the deployed schema version. Written at apply time by sem-apply
-- from the VERSION file baked into the distribution by sem-dist.
--
-- Existence-guarded via to_regclass so the script is idempotent. The original
-- table_exists() helper cannot be used here: it is dropped at the end of the
-- first bootstrap script (scripts/20130318-105434.sql).

set search_path to schema_evolution_manager;

do $$
begin
  if to_regclass('schema_evolution_manager.versions') is null then

    create table schema_evolution_manager.versions (
      id           bigserial,
      version      varchar(100) not null,
      created_at   timestamp with time zone default now() not null
    );

    alter table schema_evolution_manager.versions add constraint versions_id_pk primary key(id);

    comment on table schema_evolution_manager.versions is
      'Records the released repository version applied to this database. Latest row (max id) is the deployed schema version.';

  end if;
end$$;
