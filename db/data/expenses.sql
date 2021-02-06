-- drop table data.expenses;

create table data.expenses(
  id integer not null default nextval('data.expenses_id_seq'::regclass),
  code text not null,
  user_id integer not null,
  event_time timestamp with time zone not null,
  description text not null,
  amount integer not null,
  comment text not null,
  constraint expenses_pk primary key(id),
  constraint expenses_unique_user_id_code unique(user_id, code)
);
