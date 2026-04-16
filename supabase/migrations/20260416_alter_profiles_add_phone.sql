alter table public.profiles
  alter column email drop not null;

alter table public.profiles
  add column if not exists phone text unique;

alter table public.profiles
  drop constraint if exists profiles_email_or_phone_chk;

alter table public.profiles
  add constraint profiles_email_or_phone_chk
  check (email is not null or phone is not null);
