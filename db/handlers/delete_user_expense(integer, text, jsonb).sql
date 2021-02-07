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
