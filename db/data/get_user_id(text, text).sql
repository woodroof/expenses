-- drop function data.get_user_id(text, text);

create or replace function data.get_user_id(in_login text, in_password text)
returns integer
stable
as
$$
declare
  v_user_id integer;
  v_salt text;
  v_hash text;
begin
  assert in_login is not null;
  assert in_password is not null;

  select id, salt, hash
  into v_user_id, v_salt, v_hash
  from data.users
  where login = in_login;

  if v_user_id is null then
    return null;
  end if;

  assert v_salt is not null;
  assert v_hash is not null;

  if v_hash != pgcrypto.digest(pgcrypto.digest(in_password, 'sha512') || v_salt, 'sha512') then
    return null;
  end if;

  return v_user_id;
end;
$$
language plpgsql;
