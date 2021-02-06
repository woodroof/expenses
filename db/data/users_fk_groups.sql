alter table data.users add constraint users_fk_groups
foreign key(group_id) references data.groups(id);
