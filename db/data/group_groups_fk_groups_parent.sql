alter table data.group_groups add constraint group_groups_fk_groups_parent
foreign key(parent_group_id) references data.groups(id);
