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
