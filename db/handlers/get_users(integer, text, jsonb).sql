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
