-- Cache for Sephora "best-selling skin care" top products shown on the Home screen.
-- 4 rows total: slot 0 = hero, slot 1..3 = circle products.

create table if not exists public.sephora_popular_products_cache (
  slot integer primary key,
  name text not null,
  subtitle text not null,
  image_url text not null,
  updated_at timestamptz not null default now()
);

alter table public.sephora_popular_products_cache enable row level security;

drop policy if exists "Authenticated users can view Sephora popular products" on public.sephora_popular_products_cache;
create policy "Authenticated users can view Sephora popular products"
on public.sephora_popular_products_cache
for select
using (auth.uid() is not null);

-- Writes are done by the Edge Function using the service role key.
-- (No insert/update policies for authenticated clients.)

