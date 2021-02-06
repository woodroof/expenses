alter table data.group_groups add constraint group_groups_fk_groups
foreign key(group_id) references data.groups(id);
