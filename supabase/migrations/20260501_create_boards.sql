-- boards: one row per user-created board
CREATE TABLE boards (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own boards" ON boards FOR ALL USING (auth.uid() = user_id);

-- board_products: many-to-many link between boards and products
CREATE TABLE board_products (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id     UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    saved_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (board_id, product_name)
);
ALTER TABLE board_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own board_products" ON board_products FOR ALL USING (auth.uid() = user_id);
