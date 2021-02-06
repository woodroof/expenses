alter table data.user_groups add constraint user_groups_fk_groups
foreign key(group_id) references data.groups(id);
