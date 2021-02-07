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
