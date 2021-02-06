-- drop table data.groups;

create table data.groups(
  id integer not null default nextval('data.groups_id_seq'::regclass),
  name text,
  constraint groups_pk primary key(id)
);
