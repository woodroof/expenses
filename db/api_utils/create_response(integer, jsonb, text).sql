-- drop function api_utils.create_response(integer, jsonb, text);

create or replace function api_utils.create_response(in_code integer, in_headers jsonb default null::jsonb, in_body text default null::text)
returns jsonb
immutable
as
$$
declare
  v_retval jsonb := jsonb_build_object('code', in_code);
begin
  assert in_code is not null;

  if in_headers is not null then
    v_retval := v_retval || jsonb_build_object('headers', in_headers);
  end if;

  if in_body is not null then
    v_retval := v_retval || jsonb_build_object('body', in_body);
  end if;

  return v_retval;
end;
$$
language plpgsql;
