-- drop table data.group_groups;

create table data.group_groups(
  id integer not null default nextval('data.group_groups_id_seq'::regclass),
  group_id integer not null,
  parent_group_id integer not null,
  constraint group_groups_pk primary key(id),
  constraint group_groups_unique_group_id_parent_group_id unique(group_id, parent_group_id)
);
