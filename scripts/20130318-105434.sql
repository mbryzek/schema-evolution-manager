-- This script initializes the schema_evolution_manager schema and the scripts and
-- the bootstrap_scripts tables

create schema schema_evolution_manager;

SET search_path TO schema_evolution_manager;

create or replace function table_exists(p_schema_name character varying, p_table_name character varying) returns boolean
    language plpgsql
    as $$
begin
  perform 1 from information_schema.tables where table_schema = p_schema_name and table_name=p_table_name and table_type='BASE TABLE';
  return found;
end;
$$;

create or replace function create_tables() returns void
    language plpgsql
    as $$
begin
  if not table_exists('schema_evolution_manager', 'scripts') then

    create table schema_evolution_manager.scripts (
      id           bigserial,
      filename     varchar(100) not null,
      created_at   timestamp with time zone default now() not null
    );

    alter table schema_evolution_manager.scripts add constraint scripts_id_pk primary key(id);
    alter table schema_evolution_manager.scripts add constraint scripts_filename_un unique(filename);

    comment on table schema_evolution_manager.scripts is '
      When a script is applied to this database, the script is recorded
      here. This table is the used to ensure scripts are applied at most
      once to this database.
    ';

  end if;

  if not table_exists('schema_evolution_manager', 'bootstrap_scripts') then

    create table schema_evolution_manager.bootstrap_scripts (
      id           bigserial,
      filename     varchar(100) not null,
      created_at   timestamp with time zone default now() not null
    );

    alter table schema_evolution_manager.bootstrap_scripts add constraint bootstrap_scripts_id_pk primary key(id);
    alter table schema_evolution_manager.bootstrap_scripts add constraint bootstrap_scripts_filename_un unique(filename);

    comment on table schema_evolution_manager.bootstrap_scripts is '
      Internal list of schema_evolution_manager sql scripts applied. Used only for upgrades
      to schema_evolution_manager itself.
    ';

  end if;

end;
$$;

select create_tables();

drop function create_tables();
drop function table_exists(character varying, character varying);
