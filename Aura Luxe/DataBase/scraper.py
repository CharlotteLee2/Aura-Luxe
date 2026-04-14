#
//  scraper.py
//  Aura Luxe
//
//  Created by CharlotteLee on 4/14/26.
//

import requests
from bs4 import BeautifulSoup
import re
from supabase import create_client

# -----------------------------
# Supabase setup
# -----------------------------
SUPABASE_URL = "https://ttftciroyrdbskixmynz.supabase.co"
SUPABASE_KEY = "sb_publishable_7hIhIl6R3silizruFmOqPQ_C7CYSSqG"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# -----------------------------
# Skin type rules
# -----------------------------
rules = [
    {"keyword": r"\bsalicylic\b", "types": ["oily"]},
    {"keyword": r"\bbenzoyl\b", "types": ["oily"]},
    {"keyword": r"\bniacinamide\b", "types": ["all"]},
    {"keyword": r"\bhyaluronic\b", "types": ["dry"]},
    {"keyword": r"\bglycerin\b", "types": ["dry"]},
    {"keyword": r"\bceramide\b", "types": ["all"]},
    {"keyword": r"\bsqualane\b", "types": ["all"]},
    {"keyword": r"\bretinol\b", "types": ["all"]},
    {"keyword": r"\balpha hydroxy\b|\baha\b|\bglycolic\b|\blactic\b", "types": ["oily","sensitive"]},
    {"keyword": r"\balcohol denat\b|\balcohol\b", "types": ["sensitive"]},
    {"keyword": r"\bfragrance\b|\bparfum\b", "types": ["sensitive"]},
    {"keyword": r"\bpanthenol\b|\bprovitamin b5\b", "types": ["all","sensitive"]}
]

def classify_skin_types(ingredients):
    types = set()
    for ingredient in ingredients:
        ing_lower = ingredient.lower()
        for rule in rules:
            if re.search(rule["keyword"], ing_lower):
                types.update(rule["types"])
    return list(types) if types else ["all"]

# -----------------------------
# Get product list via search
# -----------------------------
BASE_SEARCH_URL = "https://incidecoder.com/search/product?query="

def get_product_urls_for_query(query):
    url = f"{BASE_SEARCH_URL}{query}"
    resp = requests.get(url)
    if resp.status_code != 200:
        return []
    soup = BeautifulSoup(resp.text, "html.parser")
    links = soup.select("a[href^='/products/']")
    urls = set()
    for a in links:
        href = a["href"]
        full = "https://incidecoder.com" + href
        urls.add(full)
    return list(urls)

# -----------------------------
# Scrape individual product
# -----------------------------
def scrape_product_page(url):
    resp = requests.get(url)
    if resp.status_code != 200:
        return None
    soup = BeautifulSoup(resp.text, "html.parser")

    # Product name
    name_tag = soup.find("h1")
    name = name_tag.get_text(strip=True) if name_tag else "Unknown"

    # Ingredients: find all ingredient links on this product page
    ingredients = []
    for a in soup.select("a[href^='/ingredients/']"):
        text = a.get_text(strip=True)
        if text and text.lower() != "[more]":
            ingredients.append(text)

    return {"name": name, "ingredients": ingredients}

# -----------------------------
# Main loop
# -----------------------------
all_product_urls = set()

# Try each letter A–Z (and maybe digits) to cover products
for letter in list("abcdefghijklmnopqrstuvwxyz0123456789"):
    print(f"Searching products with query: {letter}")
    urls = get_product_urls_for_query(letter)
    all_product_urls.update(urls)

print(f"Total product URLs found: {len(all_product_urls)}")

for idx, product_url in enumerate(all_product_urls, start=1):
    print(f"[{idx}/{len(all_product_urls)}] Scraping: {product_url}")
    product = scrape_product_page(product_url)
    if not product:
        continue

    name = product["name"]
    ingredients = product["ingredients"]
    skin_types = classify_skin_types(ingredients)

    print("   Name:", name)
    print("   Ingredients:", ingredients)
    print("   Skin types:", skin_types)

    # Insert into Supabase
    try:
        supabase.table("products").insert({
            "product_name": name,
            "ingredients": ingredients,
            "skin_types": skin_types
        }).execute()
    except Exception as e:
        print("   Error saving to Supabase:", e)
