-- drop function api_utils.create_unauthorized_response();

create or replace function api_utils.create_unauthorized_response()
returns jsonb
immutable
as
$$
begin
  return api_utils.create_response(401, jsonb_build_object('WWW-Authenticate', 'Basic realm="Expenses tracker", charset="UTF-8"'));
end;
$$
language plpgsql;
