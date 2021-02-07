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
