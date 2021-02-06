-- drop index data.expenses_idx_user_id;

create index expenses_idx_user_id on data.expenses(user_id);
