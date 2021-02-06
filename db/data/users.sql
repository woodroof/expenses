-- drop table data.users;

create table data.users(
  id integer not null default nextval('data.users_id_seq'::regclass),
  group_id integer not null,
  login text not null,
  salt text not null,
  hash text not null,
  is_user_manager boolean not null default false,
  constraint users_pk primary key(id),
  constraint users_unique_group_id unique(group_id),
  constraint users_unique_login unique(login)
);
