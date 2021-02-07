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
