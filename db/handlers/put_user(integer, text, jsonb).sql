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
  assert in_user_id is not null;
  assert in_params is not null;

  select unnest(regexp_matches(in_path, '^/users/([^/]+)/?$'))
  into v_login;

  select id, is_user_manager, salt
  into v_user_id, v_is_user_manager, v_salt
  from data.users
  where login = v_login;

  v_password := json.get_string_opt(in_params, 'password', null);
  v_new_is_user_manager := json.get_boolean_opt(in_params, 'is_user_manager', null);

  if (v_new_is_user_manager is not null and v_new_is_user_manager) or (v_user_id is not null and v_user_id != in_user_id) then
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
