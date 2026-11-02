-- One person can have a rider account and a driver account with the same
-- phone number, so phone numbers no longer need to be unique.
alter table profiles drop constraint if exists profiles_phone_key;
create index if not exists profiles_phone_idx on profiles (phone);
