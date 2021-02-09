-- Cleaning database

create schema if not exists database_cleanup;

create or replace function database_cleanup.clean()
returns void as
$$
declare
  v_schema_name text;
begin
  for v_schema_name in
  (
    select nspname as name
    from pg_namespace
    where nspname not like 'pg\_%' and nspname not in ('information_schema', 'database_cleanup')
  )
  loop
    execute format('drop schema %s cascade', v_schema_name);
  end loop;
end;
$$
language plpgsql;

select database_cleanup.clean();

drop schema database_cleanup cascade;

-- Creating extensions

create schema pgcrypto;
create extension pgcrypto schema pgcrypto;

-- Creating schemas

-- drop schema api;

create schema api;

-- drop schema api_utils;

create schema api_utils;

-- drop schema data;

create schema data;

-- drop schema error;

create schema error;

-- drop schema handlers;

create schema handlers;

-- drop schema json;

create schema json;

-- Creating enums

-- Creating functions

-- drop function api.api(text, text, text, text, jsonb);

create or replace function api.api(in_user text, in_password text, in_method text, in_path text, in_params jsonb)
returns jsonb
volatile
security definer
as
$$
declare
  v_user_id integer;
  v_function_name text;
  v_authorized_only boolean;
  v_result jsonb;
begin
  v_user_id := data.get_user_id(in_user, in_password);

  select function_name, authorized_only
  into v_function_name, v_authorized_only
  from data.handlers
  where
    method = lower(in_method) and
    in_path ~* path;

  if v_function_name is null then
    return api_utils.create_response(404);
  end if;

  if v_authorized_only and v_user_id is null then
    return api_utils.create_unauthorized_response();
  end if;

  execute format('select * from handlers.%s($1, $2, $3)', v_function_name)
  using v_user_id, in_path, in_params
  into v_result;

  return v_result;
exception when invalid_parameter_value then
  return api_utils.create_response(400);
when others or assert_failure then
  return api_utils.create_response(500);
end;
$$
language plpgsql;

-- drop function api_utils.create_response(integer, jsonb, jsonb);

create or replace function api_utils.create_response(in_code integer, in_headers jsonb default null::jsonb, in_body jsonb default null::jsonb)
returns jsonb
immutable
as
$$
declare
  v_retval jsonb := jsonb_build_object('code', in_code);
begin
  assert in_code is not null;

  if in_headers is not null then
    v_retval := v_retval || jsonb_build_object('headers', in_headers);
  end if;

  if in_body is not null then
    v_retval := v_retval || jsonb_build_object('body', in_body);
  end if;

  return v_retval;
end;
$$
language plpgsql;

-- drop function api_utils.create_unauthorized_response();

create or replace function api_utils.create_unauthorized_response()
returns jsonb
immutable
as
$$
begin
  return api_utils.create_response(401, jsonb_build_object('WWW-Authenticate', 'Basic realm="Expenses tracker", charset="UTF-8"'));
end;
$$
language plpgsql;

-- drop function data.create_user(text, text, boolean);

create or replace function data.create_user(in_login text, in_password text, in_is_user_manager boolean default false)
returns void
volatile
as
$$
declare
  -- todo: make table with constants)
  v_admin_group_id integer := 1;
  v_group_id integer;
  v_salt text;
  v_hash text;
  v_user_id integer;
  v_admin_user_id integer;
begin
  assert in_login is not null;
  assert in_password is not null;
  assert in_is_user_manager is not null;

  insert into data.groups(name)
  values(in_login)
  returning id into v_group_id;

  insert into data.group_groups(group_id, parent_group_id)
  values(v_admin_group_id, v_group_id);

  for v_admin_user_id in
    select user_id
    from data.user_groups
    where group_id = v_admin_group_id
  loop
    insert into data.user_groups(user_id, group_id)
    values(v_admin_user_id, v_group_id);
  end loop;

  v_salt := gen_random_uuid();
  v_hash := pgcrypto.digest(pgcrypto.digest(in_password, 'sha512') || v_salt, 'sha512');

  insert into data.users(group_id, login, salt, hash, is_user_manager)
  values(v_group_id, in_login, v_salt, v_hash, in_is_user_manager)
  returning id into v_user_id;

  insert into data.user_groups(user_id, group_id)
  values(v_user_id, v_group_id);
end;
$$
language plpgsql;

-- drop function data.get_user_id(text, text);

create or replace function data.get_user_id(in_login text, in_password text)
returns integer
stable
as
$$
declare
  v_user_id integer;
  v_salt text;
  v_hash text;
begin
  if in_login is null then
    return null;
  end if;

  assert in_password is not null;

  select id, salt, hash
  into v_user_id, v_salt, v_hash
  from data.users
  where login = in_login;

  if v_user_id is null then
    return null;
  end if;

  assert v_salt is not null;
  assert v_hash is not null;

  if v_hash != pgcrypto.digest(pgcrypto.digest(in_password, 'sha512') || v_salt, 'sha512')::text then
    return null;
  end if;

  return v_user_id;
end;
$$
language plpgsql;

-- drop function error.raise_invalid_input_param_value(text);

create or replace function error.raise_invalid_input_param_value(in_message text)
returns bigint
immutable
as
$$
begin
  assert in_message is not null;

  raise '%', in_message using errcode = 'invalid_parameter_value';
end;
$$
language plpgsql;

-- drop function error.raise_invalid_input_param_value(text, text);

create or replace function error.raise_invalid_input_param_value(in_format text, in_param text)
returns bigint
immutable
as
$$
begin
  assert in_format is not null;
  assert in_param is not null;

  raise '%', format(in_format, in_param) using errcode = 'invalid_parameter_value';
end;
$$
language plpgsql;

-- drop function handlers.delete_user(integer, text, jsonb);

create or replace function handlers.delete_user(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
volatile
as
$$
declare
  v_login text;
  v_user_id integer;
  v_group_id integer;
begin
  assert in_user_id is not null;

  select unnest(regexp_matches(in_path, '^/users/([^/]+)/?$'))
  into v_login;

  select id, group_id
  into v_user_id, v_group_id
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    declare
      v_is_user_manager boolean;
    begin
      select true
      into v_is_user_manager
      from data.users
      where id = in_user_id and is_user_manager = true;

      if v_is_user_manager is null then
        return api_utils.create_response(404);
      end if;
    end;
  end if;

  delete from data.group_groups
  where group_id = v_group_id or parent_group_id = v_group_id;

  delete from data.user_groups
  where group_id = v_group_id;

  delete from data.users
  where id = v_user_id;

  return api_utils.create_response(204);
end;
$$
language plpgsql;

-- drop function handlers.delete_user_expense(integer, text, jsonb);

create or replace function handlers.delete_user_expense(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
volatile
as
$$
declare
  v_matches text[];
  v_login text;
  v_expense text;
  v_user_id integer;
  v_group_id integer;
  v_expense_id integer;
  v_can_be_deleted boolean;
begin
  assert in_user_id is not null;

  select regexp_matches(in_path, '^/expenses/([^/]+)/([^/]+)/?$')
  into v_matches;

  v_login := v_matches[1];
  v_expense := v_matches[2];

  select id, group_id
  into v_user_id, v_group_id
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  select id
  into v_expense_id
  from data.expenses
  where
    code = v_expense and
    user_id = v_user_id;

  if v_expense_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    select true
    into v_can_be_deleted
    from data.user_groups
    where
      user_id = in_user_id and
      group_id = v_group_id;

    if v_can_be_deleted is null then
      return api_utils.create_response(404);
    end if;
  end if;

  delete from data.expenses
  where id = v_expense_id;

  return api_utils.create_response(204);
end;
$$
language plpgsql;

-- drop function handlers.get_my_users(integer, text, jsonb);

create or replace function handlers.get_my_users(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
stable
as
$$
declare
  v_user text;
  v_response jsonb = '[]'::jsonb;
begin
  assert in_user_id is not null;

  for v_user in
    select login
  from data.users
  where id = in_user_id
  union all
    select login
    from data.users
    where group_id in (
      select group_id
      from data.user_groups
      where user_id = in_user_id) and
    id != in_user_id
  order by login
  loop
    v_response := v_response || to_jsonb(v_user);
  end loop;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;

-- drop function handlers.get_user(integer, text, jsonb);

create or replace function handlers.get_user(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
stable
as
$$
declare
  v_login text;
  v_user_id integer;
  v_response jsonb;
begin
  assert in_user_id is not null;

  select unnest(regexp_matches(in_path, '^/users/([^/]+)/?$'))
  into v_login;

  select id, jsonb_build_object('login', v_login, 'is_user_manager', is_user_manager)
  into v_user_id, v_response
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    declare
      v_is_user_manager boolean;
    begin
      select true
      into v_is_user_manager
      from data.users
      where id = in_user_id and is_user_manager = true;

      if v_is_user_manager is null then
        return api_utils.create_response(404);
      end if;
    end;
  end if;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;

-- drop function handlers.get_user_expense(integer, text, jsonb);

create or replace function handlers.get_user_expense(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
stable
as
$$
declare
  v_matches text[];
  v_login text;
  v_expense text;
  v_user_id integer;
  v_group_id integer;
  v_expense_id integer;
  v_expense_visible boolean;
  v_response jsonb;
begin
  assert in_user_id is not null;

  select regexp_matches(in_path, '^/expenses/([^/]+)/([^/]+)/?$')
  into v_matches;

  v_login := v_matches[1];
  v_expense := v_matches[2];

  select id, group_id
  into v_user_id, v_group_id
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  select
    id,
    jsonb_build_object(
      'id', code,
      'author', v_login,
      'date', to_char(event_time at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS'),
      'description', description,
      'amount', amount,
      'comment', comment)
  into v_expense_id, v_response
  from data.expenses
  where
    code = v_expense and
    user_id = v_user_id;

  if v_expense_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    select true
    into v_expense_visible
    from data.user_groups
    where
      user_id = in_user_id and
      group_id = v_group_id;

    if v_expense_visible is null then
      return api_utils.create_response(404);
    end if;
  end if;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;

-- drop function handlers.get_user_expenses(integer, text, jsonb);

create or replace function handlers.get_user_expenses(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
stable
as
$$
declare
  v_login text;
  v_user_id integer;
  v_group_id integer;
  v_response jsonb;
  v_expense jsonb;
begin
  assert in_user_id is not null;

  select unnest(regexp_matches(in_path, '^/expenses/([^/]+)/?$'))
  into v_login;

  select id, group_id
  into v_user_id, v_group_id
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    declare
      v_user_expenses_visible boolean;
    begin
      select true
      into v_user_expenses_visible
      from data.user_groups
      where
        user_id = in_user_id and
        group_id = v_group_id;

      if v_user_expenses_visible is null then
        return api_utils.create_response(404);
      end if;
    end;
  end if;

  v_response := '[]'::jsonb;

  for v_expense in
    select
      jsonb_build_object(
      'id', code,
      'author', v_login,
      'date', to_char(event_time at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS'),
      'description', description,
      'amount', amount,
      'comment', comment)
    from data.expenses
    where user_id = v_user_id
    order by id
  loop
    v_response := v_response || v_expense;
  end loop;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;

-- drop function handlers.get_users(integer, text, jsonb);

create or replace function handlers.get_users(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
stable
as
$$
declare
  v_is_user_manager boolean;
  v_user jsonb;
  v_response jsonb := '[]'::jsonb;
begin
  assert in_user_id is not null;

  select is_user_manager, jsonb_build_object('login', login, 'is_user_manager', is_user_manager)
  into v_is_user_manager, v_user
  from data.users
  where id = in_user_id;

  v_response := v_response || v_user;

  if v_is_user_manager then
    for v_user in
      select jsonb_build_object('login', login, 'is_user_manager', is_user_manager)
      from data.users
      where id != in_user_id
      order by login
    loop
      v_response := v_response || v_user;
    end loop;
  end if;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;

-- drop function handlers.put_user(integer, text, jsonb);

create or replace function handlers.put_user(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
volatile
as
$$
declare
  v_login text;
  v_user_id integer;
  v_is_user_manager boolean;
  v_salt text;
  v_new_is_user_manager boolean;
  v_password text;
  v_user_data_can_be_changed boolean;
begin
  assert in_params is not null;

  select unnest(regexp_matches(in_path, '^/users/([^/]+)/?$'))
  into v_login;

  select id, is_user_manager, salt
  into v_user_id, v_is_user_manager, v_salt
  from data.users
  where login = v_login;

  v_password := json.get_string_opt(in_params, 'password', null);
  v_new_is_user_manager := json.get_boolean_opt(in_params, 'is_user_manager', null);

  if (v_new_is_user_manager is not null and v_new_is_user_manager) or (v_user_id is not null and (in_user_id is null or v_user_id != in_user_id)) then
    if in_user_id is null then
      return api_utils.create_unauthorized_response();
    end if;

    select true
    into v_user_data_can_be_changed
    from data.users
    where id = in_user_id and is_user_manager is true;

    if v_user_data_can_be_changed is null then
      return api_utils.create_response(403);
    end if;
  end if;

  if v_user_id is null then
    if v_password is null then
      return api_utils.create_response(400);
    end if;

    if v_new_is_user_manager is null then
      v_new_is_user_manager := false;
    end if;

    perform data.create_user(v_login, v_password, v_new_is_user_manager);
    return api_utils.create_response(201);
  end if;

  if v_is_user_manager is not null and v_is_user_manager != v_new_is_user_manager then
    update data.users
    set is_user_manager = v_new_is_user_manager
    where id = v_user_id;
  end if;

  if v_password is not null then
    update data.users
    set hash = pgcrypto.digest(pgcrypto.digest(v_password, 'sha512') || v_salt, 'sha512')
    where id = v_user_id;
  end if;

  return api_utils.create_response(204);
end;
$$
language plpgsql;

-- drop function handlers.put_user_expense(integer, text, jsonb);

create or replace function handlers.put_user_expense(in_user_id integer, in_path text, in_params jsonb)
returns jsonb
volatile
as
$$
declare
  v_matches text[];
  v_login text;
  v_expense text;
  v_user_id integer;
  v_group_id integer;
  v_can_be_edited boolean;
  v_expense_id integer;
  v_date text;
  v_time timestamp with time zone;
  v_description text;
  v_amount integer;
  v_comment text;
begin
  assert in_user_id is not null;
  assert in_params is not null;

  select regexp_matches(in_path, '^/expenses/([^/]+)/([^/]+)/?$')
  into v_matches;

  v_login := v_matches[1];
  v_expense := v_matches[2];

  select id, group_id
  into v_user_id, v_group_id
  from data.users
  where login = v_login;

  if v_user_id is null then
    return api_utils.create_response(404);
  end if;

  if v_user_id != in_user_id then
    select true
    into v_can_be_edited
    from data.user_groups
    where
      user_id = in_user_id and
      group_id = v_group_id;

    if v_can_be_edited is null then
      return api_utils.create_response(404);
    end if;
  end if;

  select id
  into v_expense_id
  from data.expenses
  where code = v_expense and user_id = v_user_id;

  v_date := json.get_string(in_params, 'date');
  begin
    v_time := v_date::timestamp at time zone 'UTC';
  exception when others then
    perform error.raise_invalid_input_param_value('Invalid date');
  end;

  v_description := json.get_string(in_params, 'description');
  v_amount := json.get_integer(in_params, 'amount');
  if v_amount < 0 then
    perform error.raise_invalid_input_param_value('Negative amount');
  end if;

  v_comment := json.get_string(in_params, 'comment');

  if v_expense_id is null then
    insert into data.expenses(code, user_id, event_time, description, amount, comment)
    values(v_expense, v_user_id, v_time, v_description, v_amount, v_comment);

    return api_utils.create_response(201);
  end if;

  update data.expenses
  set
    event_time = v_time,
    description = v_description,
    amount = v_amount,
    comment = v_comment
  where id = v_expense_id;

  return api_utils.create_response(204);
end;
$$
language plpgsql;

-- drop function json.get_boolean_opt(jsonb, text, boolean);

create or replace function json.get_boolean_opt(in_json jsonb, in_name text, in_default boolean)
returns boolean
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'boolean' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a boolean', in_name);
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_integer(jsonb, text);

create or replace function json.get_integer(in_json jsonb, in_name text default null::text)
returns integer
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
  v_ret_val integer;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'number' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a number', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'number' then
    perform error.raise_invalid_input_param_value('Json is not a number');
  end if;

  begin
    v_ret_val := v_param;
  exception when others then
    if in_name is not null then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an integer', in_name);
    else
      perform error.raise_invalid_input_param_value('Json is not an integer');
    end if;
  end;

  return v_ret_val;
end;
$$
language plpgsql;

-- drop function json.get_object(jsonb, text);

create or replace function json.get_object(in_json jsonb, in_name text default null::text)
returns jsonb
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'object' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not an object', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'object' then
    perform error.raise_invalid_input_param_value('Json is not an object');
  end if;

  return v_param;
end;
$$
language plpgsql;

-- drop function json.get_string(jsonb, text);

create or replace function json.get_string(in_json jsonb, in_name text default null::text)
returns text
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  if in_name is not null then
    v_param := json.get_object(in_json)->in_name;
  else
    v_param := in_json;
  end if;

  v_param_type := jsonb_typeof(v_param);

  if in_name is not null then
    if v_param_type is null then
      perform error.raise_invalid_input_param_value('Attribute "%s" was not found', in_name);
    end if;
    if v_param_type != 'string' then
      perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
    end if;
  elseif v_param_type is null or v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Json is not a string');
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- drop function json.get_string_opt(jsonb, text, text);

create or replace function json.get_string_opt(in_json jsonb, in_name text, in_default text)
returns text
immutable
as
$$
declare
  v_param jsonb;
  v_param_type text;
begin
  assert in_name is not null;

  v_param := json.get_object(in_json)->in_name;

  v_param_type := jsonb_typeof(v_param);

  if v_param_type is null or v_param_type = 'null' then
    return in_default;
  end if;

  if v_param_type != 'string' then
    perform error.raise_invalid_input_param_value('Attribute "%s" is not a string', in_name);
  end if;

  return v_param#>>'{}';
end;
$$
language plpgsql;

-- Creating tables

-- drop table data.expenses;

create table data.expenses(
  id integer not null default nextval('data.expenses_id_seq'::regclass),
  code text not null,
  user_id integer not null,
  event_time timestamp with time zone not null,
  description text not null,
  amount integer not null,
  comment text not null,
  constraint expenses_pk primary key(id),
  constraint expenses_unique_user_id_code unique(user_id, code)
);

-- drop table data.group_groups;

create table data.group_groups(
  id integer not null default nextval('data.group_groups_id_seq'::regclass),
  group_id integer not null,
  parent_group_id integer not null,
  constraint group_groups_pk primary key(id),
  constraint group_groups_unique_group_id_parent_group_id unique(group_id, parent_group_id)
);

-- drop table data.groups;

create table data.groups(
  id integer not null default nextval('data.groups_id_seq'::regclass),
  name text,
  constraint groups_pk primary key(id)
);

-- drop table data.handlers;

create table data.handlers(
  id integer not null default nextval('data.handlers_id_seq'::regclass),
  method text not null,
  path text not null,
  function_name text not null,
  authorized_only boolean not null,
  constraint handlers_pk primary key(id),
  constraint handlers_unique_method_path unique(method, path)
);

-- drop table data.user_groups;

create table data.user_groups(
  id integer not null default nextval('data.user_groups_id_seq'::regclass),
  user_id integer not null,
  group_id integer not null,
  constraint user_groups_pk primary key(id),
  constraint user_groups_unique_user_id_group_id unique(user_id, group_id)
);

-- drop table data.users;

create table data.users(
  id integer not null default nextval('data.users_id_seq'::regclass),
  group_id integer not null,
  login text not null,
  salt text not null,
  hash text not null,
  is_user_manager boolean not null default false,
  constraint users_pk primary key(id),
  constraint users_unique_group_id unique(group_id),
  constraint users_unique_login unique(login)
);

-- Creating foreign keys

alter table data.expenses add constraint expenses_fk_users
foreign key(user_id) references data.users(id);

alter table data.group_groups add constraint group_groups_fk_groups
foreign key(group_id) references data.groups(id);

alter table data.group_groups add constraint group_groups_fk_groups_parent
foreign key(parent_group_id) references data.groups(id);

alter table data.user_groups add constraint user_groups_fk_groups
foreign key(group_id) references data.groups(id);

alter table data.users add constraint users_fk_groups
foreign key(group_id) references data.groups(id);

-- Creating indexes

-- drop index data.expenses_idx_user_id;

create index expenses_idx_user_id on data.expenses(user_id);

-- Creating triggers

-- Initial data

insert into data.groups(name) values('admins'); -- 1

select data.create_user('admin', 'admin', true); -- 1

insert into data.group_groups(group_id, parent_group_id) values(2, 1);
insert into data.user_groups(user_id, group_id) values(1, 1);

select data.create_user('user_manager', 'user_manager', true);
select data.create_user('user', 'user', false);
select data.create_user('extended_user', 'extended_user', false); -- 4

insert into data.group_groups(group_id, parent_group_id) values(5, 4);
insert into data.user_groups(user_id, group_id) values(4, 4);

insert into data.handlers(method, path, function_name, authorized_only)
values
  ('get', '^/users/?$', 'get_users', true),
  ('get', '^/my_users/?$', 'get_my_users', true),
  ('get', '^/users/[^/]+/?$', 'get_user', true),
  ('get', '^/expenses/[^/]+/?$', 'get_user_expenses', true),
  ('get', '^/expenses/[^/]+/[^/]+/?$', 'get_user_expense', true),
  ('put', '^/users/[^/]+/?$', 'put_user', false),
  ('put', '^/expenses/[^/]+/[^/]+/?$', 'put_user_expense', true),
  ('delete', '^/users/[^/]+/?$', 'delete_user', true),
  ('delete', '^/expenses/[^/]+/[^/]+/?$', 'delete_user_expense', true);

select handlers.put_user_expense(1, '/expenses/admin/1', '{"date": "2021-01-01 12:00:00", "description": "nearby shop", "amount": 1, "comment": "recreation"}');
select handlers.put_user_expense(2, '/expenses/user_manager/1', '{"date": "2021-01-02 12:00:00", "description": "steam", "amount": 2, "comment": "cyberpunk"}');
select handlers.put_user_expense(3, '/expenses/user/1', '{"date": "2021-01-03 12:00:00", "description": "online shop", "amount": 3, "comment": "clothes"}');
select handlers.put_user_expense(4, '/expenses/extended_user/1', '{"date": "2021-01-04 12:00:00", "description": "gas station", "amount": 4, "comment": "gas & chocolate"}');
select handlers.put_user_expense(4, '/expenses/extended_user/2', '{"date": "2021-01-04 13:00:00", "description": "gas station", "amount": 2, "comment": "more chocolate"}');
select handlers.put_user_expense(4, '/expenses/extended_user/3', '{"date": "2021-01-04 14:00:00", "description": "gas station", "amount": 2, "comment": "even more chocolate"}');

drop role if exists http;
create role http noinherit login password 'http';
grant usage on schema api to http;
