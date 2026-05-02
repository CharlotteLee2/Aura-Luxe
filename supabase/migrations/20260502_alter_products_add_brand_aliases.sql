ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS brand TEXT,
  ADD COLUMN IF NOT EXISTS aliases TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS products_brand_idx ON public.products (brand);
CREATE INDEX IF NOT EXISTS products_aliases_gin_idx ON public.products USING GIN (aliases);

-- RPC for fuzzy product search across name, brand, and aliases
CREATE OR REPLACE FUNCTION search_products_fuzzy(q TEXT)
RETURNS SETOF products LANGUAGE SQL STABLE AS $$
  SELECT * FROM products
  WHERE product_name ILIKE '%' || q || '%'
     OR brand ILIKE '%' || q || '%'
     OR q ILIKE ANY(aliases)
  LIMIT 5;
$$;
