create table if not exists public.skincare_routine (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_name text not null,
  time_of_use text not null check (time_of_use in ('morning', 'night', 'both')),
  created_at timestamptz not null default now()
);

alter table public.skincare_routine enable row level security;

drop policy if exists "Users can view own routine" on public.skincare_routine;
create policy "Users can view own routine"
  on public.skincare_routine for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own routine" on public.skincare_routine;
create policy "Users can insert own routine"
  on public.skincare_routine for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own routine" on public.skincare_routine;
create policy "Users can delete own routine"
  on public.skincare_routine for delete
  using (auth.uid() = user_id);
