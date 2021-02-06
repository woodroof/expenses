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
    user_id = in_user_in and
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
