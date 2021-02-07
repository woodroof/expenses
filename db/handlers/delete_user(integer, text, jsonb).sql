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
