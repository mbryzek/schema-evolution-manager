-- Records the released repository version applied to this database. The latest
-- row (max id) is the deployed schema version. Written at apply time by sem-apply
-- from the VERSION file baked into the distribution by sem-dist.

set search_path to schema_evolution_manager;

create table schema_evolution_manager.versions (
  id           bigserial,
  version      varchar(100) not null,
  created_at   timestamp with time zone default now() not null
);

alter table schema_evolution_manager.versions add constraint versions_id_pk primary key(id);

comment on table schema_evolution_manager.versions is
  'Records the released repository version applied to this database. Latest row (max id) is the deployed schema version.';
