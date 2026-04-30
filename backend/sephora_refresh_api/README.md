# Sephora Refresh API

Small backend service that refreshes `sephora_popular_products_cache` with the top 4 products from Sephora.

## Endpoints

- `GET /health` -> basic health check
- `POST /refresh-sephora-popular` -> scrape + upsert slots 0..3

## Environment Variables

- `SUPABASE_URL` (required)
- `SUPABASE_SERVICE_ROLE_KEY` (required)
- `REFRESH_TOKEN` (optional, recommended)

If `REFRESH_TOKEN` is set, clients must send:

`Authorization: Bearer <REFRESH_TOKEN>`

## Run Locally

```bash
cd backend/sephora_refresh_api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export SUPABASE_URL="https://ttftciroyrdbskixmynz.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
export REFRESH_TOKEN="YOUR_REFRESH_TOKEN"
uvicorn app:app --host 0.0.0.0 --port 8080
```

## App Integration

In `Aura Luxe/Services/SephoraPopularProductsService.swift`, set:

`backendRefreshURLString = "https://<your-deployed-host>/refresh-sephora-popular"`

If you enable `REFRESH_TOKEN`, add the same token to request headers in Swift.
