-- library of common utility functions
set search_path to schema_evolution_manager;

CREATE OR REPLACE FUNCTION create_basic_audit_data(p_schema_name character varying, p_table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  perform schema_evolution_manager.create_basic_created_audit_data(p_schema_name, p_table_name);
  perform schema_evolution_manager.create_basic_updated_audit_data(p_schema_name, p_table_name);
  perform schema_evolution_manager.create_basic_deleted_audit_data(p_schema_name, p_table_name);
end;
$$;

CREATE OR REPLACE FUNCTION create_basic_created_audit_data(p_schema_name character varying, p_table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add created_by_guid uuid not null';
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add created_at timestamp with time zone default now() not null';
end;
$$;

CREATE OR REPLACE FUNCTION create_basic_deleted_audit_data(p_schema_name character varying, p_table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add deleted_by_guid uuid';
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add deleted_at timestamp with time zone';
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add constraint ' || p_table_name || '_deleted_ck ' ||
          'check ( (deleted_at is null and deleted_by_guid is null) OR (deleted_at is not null and deleted_by_guid is not null) )';
  perform schema_evolution_manager.create_prevent_immediate_delete_trigger(p_schema_name, p_table_name);
end;
$$;

CREATE OR REPLACE FUNCTION create_basic_updated_audit_data(p_schema_name character varying, p_table_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add updated_by_guid uuid not null';
  execute 'alter table ' || p_schema_name || '.' || p_table_name || ' add updated_at timestamp with time zone default now() not null';
  perform schema_evolution_manager.create_updated_at_trigger(p_schema_name, p_table_name);
end;
$$;

CREATE OR REPLACE FUNCTION prevent_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'Physical deletes are not allowed on this table';
end;
$$;

CREATE OR REPLACE FUNCTION prevent_immediate_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if old.deleted_at is null then
    raise exception 'You must set the deleted_at column for this table';
  end if;

  if old.deleted_at > now() - interval '1 months' then
    raise exception 'Physical deletes on this table can occur only after 1 month of deleting the records';
  end if;

  return old;
end;
$$;

CREATE OR REPLACE FUNCTION create_updated_at_trigger(p_schema_name character varying, p_table_name character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare
  v_name varchar;
begin
  v_name = p_table_name || '_updated_at_trigger';
  execute 'drop trigger if exists ' || v_name || ' on ' || p_schema_name || '.' || p_table_name;
  execute 'create trigger ' || v_name || ' before update on ' || p_schema_name || '.' || p_table_name || ' for each row execute procedure schema_evolution_manager.set_updated_at_trigger_function()';
  return v_name;
end;
$$;

CREATE OR REPLACE FUNCTION set_updated_at_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if (new.updated_at = old.updated_at) then
    new.updated_at = timezone('utc', now())::timestamptz;
  end if;
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION create_prevent_immediate_delete_trigger(p_schema_name character varying, p_table_name character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare
  v_name varchar;
begin
  v_name = p_table_name || '_prevent_immediate_delete_trigger';
  execute 'create trigger ' || v_name || ' before delete on ' || p_schema_name || '.' || p_table_name || ' for each row execute procedure schema_evolution_manager.prevent_immediate_delete()';
  return v_name;
end;
$$;

CREATE OR REPLACE FUNCTION create_prevent_update_trigger(p_schema_name character varying, p_table_name character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare
  v_name varchar;
begin
  v_name = p_table_name || '_prevent_update_trigger';
  execute 'create trigger ' || v_name || ' after update on ' || p_schema_name || '.' || p_table_name || ' for each row execute procedure schema_evolution_manager.prevent_update()';
  return v_name;
end;
$$;

CREATE OR REPLACE FUNCTION create_prevent_delete_trigger(p_schema_name character varying, p_table_name character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare
  v_name varchar;
begin
  v_name = p_table_name || '_prevent_delete_trigger';
  execute 'create trigger ' || v_name || ' after delete on ' || p_schema_name || '.' || p_table_name || ' for each row execute procedure schema_evolution_manager.prevent_delete()';
  return v_name;
end;
$$;

CREATE OR REPLACE FUNCTION prevent_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'Physical updates are not allowed on this table';
end;
$$;
