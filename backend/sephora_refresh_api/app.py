import os
import re
from typing import List, Dict
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException, Request
from supabase import create_client

app = FastAPI(title="Aura Luxe Sephora Refresh API")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
REFRESH_TOKEN = os.getenv("REFRESH_TOKEN", "").strip()

SEPHORA_LIST_URL = "https://www.sephora.com/beauty/best-selling-skin-care"
SEPHORA_FALLBACK_URL = "https://www.sephora.com/shop/skincare?sortBy=BEST_SELLING"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.google.com/",
}


def _get_supabase():
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def fetch_html(url: str) -> str:
    response = requests.get(url, headers=HEADERS, timeout=25)
    if response.ok:
        return response.text

    if response.status_code == 403:
        try:
            import cloudscraper  # type: ignore

            scraper = cloudscraper.create_scraper(
                browser={"browser": "chrome", "platform": "darwin", "mobile": False}
            )
            response = scraper.get(url, headers=HEADERS, timeout=30)
            if response.ok:
                return response.text
        except Exception:
            pass

    response.raise_for_status()
    return response.text


def normalize_product_url(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip()
    if "/product/" not in value:
        return None
    if value.startswith("//"):
        value = "https:" + value
    elif value.startswith("/"):
        value = "https://www.sephora.com" + value
    elif not value.startswith("http://") and not value.startswith("https://"):
        value = "https://www.sephora.com/" + value.lstrip("/")
    return value


def normalize_image_url(value: str | None, page_url: str) -> str | None:
    if not value:
        return None
    value = value.strip()
    if not value:
        return None
    if value.startswith("//"):
        return "https:" + value
    return urljoin(page_url, value)


def looks_like_logo_or_placeholder(url: str) -> bool:
    lowered = url.lower()
    blocked_tokens = (
        "logo",
        "favicon",
        "placeholder",
        "sprite",
        "icon",
        "social-share",
        "socialshare",
        "apple-touch-icon",
    )
    return any(token in lowered for token in blocked_tokens)


def extract_product_image(soup: BeautifulSoup, html: str, page_url: str) -> str | None:
    candidates: List[str] = []

    def add_candidate(raw: str | None):
        normalized = normalize_image_url(raw, page_url)
        if normalized and normalized not in candidates:
            candidates.append(normalized)

    for prop in ("og:image:secure_url", "og:image", "twitter:image"):
        tag = soup.find("meta", attrs={"property": prop}) or soup.find(
            "meta", attrs={"name": prop}
        )
        if tag:
            add_candidate(tag.get("content"))

    for img in soup.select("img"):
        add_candidate(img.get("src"))
        add_candidate(img.get("data-src"))
        add_candidate(img.get("data-lazy-src"))
        srcset = img.get("srcset") or img.get("data-srcset")
        if srcset:
            first = srcset.split(",")[0].strip().split(" ")[0].strip()
            add_candidate(first)

    regex_hits = re.findall(r"https?://[^\s\"')>]+", html)
    for hit in regex_hits:
        if any(ext in hit.lower() for ext in (".jpg", ".jpeg", ".png", ".webp", ".avif")):
            add_candidate(hit)

    filtered = [url for url in candidates if not looks_like_logo_or_placeholder(url)]
    if not filtered:
        return None

    for url in filtered:
        if "productimages" in url.lower():
            return url
    return filtered[0]


def extract_product_links(html: str) -> List[str]:
    soup = BeautifulSoup(html, "html.parser")
    links: List[str] = []

    for anchor in soup.select("a[href*='/product/']"):
        url = normalize_product_url(anchor.get("href"))
        if url and url not in links:
            links.append(url)

    if len(links) < 4:
        patterns = [
            r"https?://www\.sephora\.com/product/[^\s\"')]+",
            r"/product/[A-Za-z0-9\-\._~/%\?=&]+",
        ]
        for pattern in patterns:
            for raw in re.findall(pattern, html):
                url = normalize_product_url(raw)
                if url and url not in links:
                    links.append(url)
                if len(links) >= 4:
                    break
            if len(links) >= 4:
                break

    return links[:4]


def scrape_product(url: str) -> tuple[str, str]:
    html = fetch_html(url)
    soup = BeautifulSoup(html, "html.parser")

    name_tag = soup.find("h1")

    name = name_tag.get_text(strip=True) if name_tag else None
    image_url = extract_product_image(soup, html, url)

    if not name or not image_url:
        raise ValueError(f"Could not parse product data from {url}")

    return name, image_url


def build_rows() -> List[Dict[str, str | int]]:
    links = extract_product_links(fetch_html(SEPHORA_LIST_URL))
    if len(links) < 4:
        for link in extract_product_links(fetch_html(SEPHORA_FALLBACK_URL)):
            if link not in links:
                links.append(link)
            if len(links) >= 4:
                break

    if len(links) < 4:
        raise RuntimeError(f"Expected 4 product links, got {len(links)}")

    subtitles = [
        "Trending now on Sephora",
        "Popular pick",
        "Popular pick",
        "Popular pick",
    ]

    rows: List[Dict[str, str | int]] = []
    for slot in range(4):
        name, image_url = scrape_product(links[slot])
        rows.append(
            {
                "slot": slot,
                "name": name,
                "subtitle": subtitles[slot],
                "image_url": image_url,
            }
        )
    return rows


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/refresh-sephora-popular")
async def refresh_sephora_popular(request: Request):
    if REFRESH_TOKEN:
        auth = request.headers.get("authorization", "")
        if auth != f"Bearer {REFRESH_TOKEN}":
            raise HTTPException(status_code=401, detail="Unauthorized")

    try:
        rows = build_rows()
        supabase = _get_supabase()
        supabase.table("sephora_popular_products_cache").upsert(
            rows, on_conflict="slot"
        ).execute()
        return {"ok": True, "count": len(rows), "products": rows}
    except Exception as err:
        raise HTTPException(status_code=500, detail=str(err))

