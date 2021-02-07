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
    where group_id in (
      select group_id
      from data.user_groups
      where user_id = in_user_id)
  loop
    v_response := v_response || to_jsonb(v_user);
  end loop;

  return api_utils.create_response(200, jsonb_build_object('Content-Type', 'application/json'), v_response);
end;
$$
language plpgsql;
