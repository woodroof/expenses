-- drop table data.handlers;

create table data.handlers(
  id integer not null default nextval('data.handlers_id_seq'::regclass),
  method text not null,
  path text not null,
  function_name text not null,
  constraint handlers_pk primary key(id),
  constraint handlers_unique_method_path unique(method, path)
);
