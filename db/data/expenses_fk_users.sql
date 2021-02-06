alter table data.expenses add constraint expenses_fk_users
foreign key(user_id) references data.users(id);
