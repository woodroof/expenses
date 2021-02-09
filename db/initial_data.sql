insert into data.groups(name) values('admins'); -- 1

select data.create_user('admin', 'admin', true); -- 1

insert into data.group_groups(group_id, parent_group_id) values(2, 1);
insert into data.user_groups(user_id, group_id) values(1, 1);

select data.create_user('user_manager', 'user_manager', true);
select data.create_user('user', 'user', false);
select data.create_user('extended_user', 'extended_user', false); -- 4

insert into data.group_groups(group_id, parent_group_id) values(5, 4);
insert into data.user_groups(user_id, group_id) values(4, 4);

insert into data.handlers(method, path, function_name, authorized_only)
values
  ('get', '^/users/?$', 'get_users', true),
  ('get', '^/my_users/?$', 'get_my_users', true),
  ('get', '^/users/[^/]+/?$', 'get_user', true),
  ('get', '^/expenses/[^/]+/?$', 'get_user_expenses', true),
  ('get', '^/expenses/[^/]+/[^/]+/?$', 'get_user_expense', true),
  ('put', '^/users/[^/]+/?$', 'put_user', false),
  ('put', '^/expenses/[^/]+/[^/]+/?$', 'put_user_expense', true),
  ('delete', '^/users/[^/]+/?$', 'delete_user', true),
  ('delete', '^/expenses/[^/]+/[^/]+/?$', 'delete_user_expense', true);

select handlers.put_user_expense(1, '/expenses/admin/1', '{"date": "2021-01-01 12:00:00", "description": "nearby shop", "amount": 1, "comment": "recreation"}');
select handlers.put_user_expense(2, '/expenses/user_manager/1', '{"date": "2021-01-02 12:00:00", "description": "steam", "amount": 2, "comment": "cyberpunk"}');
select handlers.put_user_expense(3, '/expenses/user/1', '{"date": "2021-01-03 12:00:00", "description": "online shop", "amount": 3, "comment": "clothes"}');
select handlers.put_user_expense(4, '/expenses/extended_user/1', '{"date": "2021-01-04 12:00:00", "description": "gas station", "amount": 4, "comment": "gas & chocolate"}');
select handlers.put_user_expense(4, '/expenses/extended_user/2', '{"date": "2021-01-04 13:00:00", "description": "gas station", "amount": 2, "comment": "more chocolate"}');
select handlers.put_user_expense(4, '/expenses/extended_user/3', '{"date": "2021-01-04 14:00:00", "description": "gas station", "amount": 2, "comment": "even more chocolate"}');

drop role if exists http;
create role http noinherit login password 'http';
grant usage on schema api to http;
