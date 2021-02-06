insert into data.groups(name) values('admins'); --1

select data.create_user('admin', 'admin', true); -- 1

insert into data.user_groups(user_id, group_id)
values(1, 1);

insert into data.handlers(method, path, function_name)
values
  ('get', '^/users/?$', 'get_users'),
  ('get', '^/my_users/?$', 'get_my_users'),
  ('get', '^/users/[^/]+/?$', 'get_user'),
  ('get', '^/expenses/[^/]+/?$', 'get_user_expenses'),
  ('get', '^/expenses/[^/]+/[^/]+/?$', 'get_user_expense'),
  ('put', '^/users/[^/]+/?$', 'put_user'),
  ('put', '^/expenses/[^/]+/[^/]+/?$', 'put_user_expense'),
  ('delete', '^/users/[^/]+/?$', 'delete_user'),
  ('delete', '^/expenses/[^/]+/[^/]+/?$', 'delete_user_expense');

drop role if exists http;
create role http noinherit login password 'http';
grant usage on schema api to http;
