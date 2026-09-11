create table if not exists public.liked_products (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users (id) on delete cascade,
  product_name text        not null,
  liked_at     timestamptz not null default now(),
  constraint liked_products_user_product_unique unique (user_id, product_name)
);

create index if not exists liked_products_user_id_idx
  on public.liked_products (user_id);

alter table public.liked_products enable row level security;

create policy "Users can view own liked products"
  on public.liked_products for select using (auth.uid() = user_id);

create policy "Users can insert own liked products"
  on public.liked_products for insert with check (auth.uid() = user_id);

create policy "Users can delete own liked products"
  on public.liked_products for delete using (auth.uid() = user_id);
