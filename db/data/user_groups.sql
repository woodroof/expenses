-- drop table data.user_groups;

create table data.user_groups(
  id integer not null default nextval('data.user_groups_id_seq'::regclass),
  user_id integer not null,
  group_id integer not null,
  constraint user_groups_pk primary key(id),
  constraint user_groups_unique_user_id_group_id unique(user_id, group_id)
);
