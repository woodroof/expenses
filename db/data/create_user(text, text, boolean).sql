-- drop function data.create_user(text, text, boolean);

create or replace function data.create_user(in_login text, in_password text, in_is_user_manager boolean default false)
returns void
volatile
as
$$
declare
  -- todo: make table with constants)
  v_admin_group_id integer := 1;
  v_group_id integer;
  v_salt text;
  v_hash text;
  v_user_id integer;
  v_admin_user_id integer;
begin
  assert in_login is not null;
  assert in_password is not null;
  assert in_is_user_manager is not null;

  insert into data.groups(name)
  values(in_login)
  returning id into v_group_id;

  insert into data.group_groups(group_id, parent_group_id)
  values(v_admin_group_id, v_group_id);

  for v_admin_user_id in
    select user_id
    from data.user_groups
    where group_id = v_admin_group_id
  loop
    insert into data.user_groups(user_id, group_id)
    values(v_admin_user_id, v_group_id);
  end loop;

  v_salt := gen_random_uuid();
  v_hash := pgcrypto.digest(pgcrypto.digest(in_password, 'sha512') || v_salt, 'sha512');

  insert into data.users(group_id, login, salt, hash, is_user_manager)
  values(v_group_id, in_login, v_salt, v_hash, in_is_user_manager)
  returning id into v_user_id;

  insert into data.user_groups(user_id, group_id)
  values(v_user_id, v_group_id);
end;
$$
language plpgsql;
