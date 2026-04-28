alter table public.profiles
  add column if not exists completed_at timestamptz;

create table if not exists public.onboarding_quiz_responses (
  user_id uuid primary key references auth.users (id) on delete cascade,
  skin_after_cleansing text not null,
  oiliness_during_day text not null,
  sensitivity_level text not null,
  concerns text[] not null,
  breakout_frequency text,
  routine_level text not null,
  product_preference text not null,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint onboarding_concerns_count_chk check (cardinality(concerns) between 1 and 3)
);

create or replace function public.set_onboarding_quiz_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_onboarding_quiz_updated_at on public.onboarding_quiz_responses;
create trigger trg_onboarding_quiz_updated_at
before update on public.onboarding_quiz_responses
for each row
execute function public.set_onboarding_quiz_updated_at();

alter table public.onboarding_quiz_responses enable row level security;

drop policy if exists "Users can view own onboarding quiz" on public.onboarding_quiz_responses;
create policy "Users can view own onboarding quiz"
on public.onboarding_quiz_responses
for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert own onboarding quiz" on public.onboarding_quiz_responses;
create policy "Users can insert own onboarding quiz"
on public.onboarding_quiz_responses
for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update own onboarding quiz" on public.onboarding_quiz_responses;
create policy "Users can update own onboarding quiz"
on public.onboarding_quiz_responses
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
