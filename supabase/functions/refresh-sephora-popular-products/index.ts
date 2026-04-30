import { createClient } from "npm:@supabase/supabase-js@2";
import * as cheerio from "npm:cheerio@1.0.0-rc.12";

const SEPHORA_BEST_SELLING_URL =
  "https://www.sephora.com/beauty/best-selling-skin-care";
const SEPHORA_FALLBACK_LIST_URL =
  "https://www.sephora.com/shop/skincare?sortBy=BEST_SELLING";
const JINA_PROXY_PREFIX = "https://r.jina.ai/http://";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function stripHtmlText(text: string) {
  return text.replace(/\s+/g, " ").trim();
}

async function fetchHtml(url: string): Promise<string> {
  const resp = await fetch(url, {
    method: "GET",
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; AuraLuxeBot/1.0)",
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Referer": "https://www.google.com/",
      "Accept-Language": "en-US,en;q=0.9",
    },
  });
  if (resp.ok) {
    return await resp.text();
  }

  // Sephora can return 403 to bots; fall back to jina.ai read-proxy.
  if (resp.status === 403) {
    const proxyURL = `${JINA_PROXY_PREFIX}${url.replace(/^https?:\/\//, "")}`;
    const proxyResp = await fetch(proxyURL, { method: "GET" });
    if (proxyResp.ok) {
      return await proxyResp.text();
    }
    throw new Error(
      `Failed to fetch ${url}: ${resp.status} ${resp.statusText}; proxy failed with ${proxyResp.status}`,
    );
  }

  throw new Error(`Failed to fetch ${url}: ${resp.status} ${resp.statusText}`);
}

function extractProductLinks(listHtml: string): string[] {
  const $ = cheerio.load(listHtml);
  const hrefs = $("a[href*='/product/']")
    .map((_, el) => $(el).attr("href"))
    .get()
    .filter((h): h is string => typeof h === "string");

  const normalized = hrefs
    .map((h) => {
      // Handle both relative "/product/..." and absolute "https://.../product/..."
      if (h.startsWith("http://") || h.startsWith("https://")) return h;
      if (h.startsWith("/")) return `https://www.sephora.com${h}`;
      return h;
    })
    .filter((h) => h.includes("/product/"));

  const deduped: string[] = [];
  const seen = new Set<string>();
  for (const u of normalized) {
    if (!seen.has(u)) {
      seen.add(u);
      deduped.push(u);
    }
    if (deduped.length >= 4) break;
  }

  // Fallback patterns for proxy-markdown and JSON/script responses.
  const patterns = [
    /https?:\/\/www\.sephora\.com\/product\/[^\s)\]"']+/g,
    /\/product\/[A-Za-z0-9\-._~/?=&%]+/g,
    /\\\/product\\\/[A-Za-z0-9\\\-._~/?=&%]+/g,
  ];
  for (const pattern of patterns) {
    if (deduped.length >= 4) break;
    const matches = listHtml.match(pattern) ?? [];
    for (const raw of matches) {
      let candidate = raw;
      candidate = candidate.replace(/\\\//g, "/"); // unescape JSON path segments
      candidate = candidate.replace(/[)\]"'\\]+$/, "");
      if (!candidate.startsWith("http://") && !candidate.startsWith("https://")) {
        candidate = `https://www.sephora.com${candidate}`;
      }
      if (!candidate.includes("/product/")) continue;
      if (!seen.has(candidate)) {
        seen.add(candidate);
        deduped.push(candidate);
      }
      if (deduped.length >= 4) break;
    }
  }

  return deduped;
}

function parseProductPage(html: string): { name: string; imageUrl: string } {
  const $ = cheerio.load(html);

  let name = stripHtmlText($("h1").first().text() || "");
  let imageUrl = stripHtmlText($("meta[property='og:image']").attr("content") || "");

  // Fallback for proxy-markdown pages.
  if (!name) {
    const line = html
      .split("\n")
      .map((s) => s.trim())
      .find((s) => s.startsWith("# ") && !s.toLowerCase().includes("sephora"));
    if (line) name = line.replace(/^#\s+/, "").trim();
  }
  if (!imageUrl) {
    const match = html.match(/https?:\/\/www\.sephora\.com\/productimages\/[^\s)"']+/);
    if (match) {
      imageUrl = match[0];
    }
  }

  if (!name || !imageUrl) {
    throw new Error("Could not parse product page name/image.");
  }
  return { name, imageUrl };
}

async function refreshCache(): Promise<
  Array<{ slot: number; name: string; subtitle: string; imageUrl: string }>
> {
  const primaryListHtml = await fetchHtml(SEPHORA_BEST_SELLING_URL);
  let productLinks = extractProductLinks(primaryListHtml);
  if (productLinks.length < 4) {
    const fallbackListHtml = await fetchHtml(SEPHORA_FALLBACK_LIST_URL);
    const fallbackLinks = extractProductLinks(fallbackListHtml);
    const merged: string[] = [];
    const seen = new Set<string>();
    for (const link of [...productLinks, ...fallbackLinks]) {
      if (!seen.has(link)) {
        seen.add(link);
        merged.push(link);
      }
      if (merged.length >= 4) break;
    }
    productLinks = merged;
  }
  if (productLinks.length < 4) {
    throw new Error(`Expected 4 product links, got ${productLinks.length}`);
  }

  const subtitles = [
    "Trending now on Sephora",
    "Popular pick",
    "Popular pick",
    "Popular pick",
  ];

  const products: Array<{
    slot: number;
    name: string;
    subtitle: string;
    imageUrl: string;
  }> = [];

  for (let i = 0; i < 4; i++) {
    const link = productLinks[i];
    const productHtml = await fetchHtml(link);
    const parsed = parseProductPage(productHtml);

    products.push({
      slot: i,
      name: parsed.name,
      subtitle: subtitles[i] ?? "Popular pick",
      imageUrl: parsed.imageUrl,
    });
  }

  return products;
}

async function readExistingCache(
  supabase: ReturnType<typeof createClient>,
): Promise<Array<{ slot: number; name: string; subtitle: string; imageUrl: string }>> {
  const { data, error } = await supabase
    .from("sephora_popular_products_cache")
    .select("slot, name, subtitle, image_url")
    .order("slot", { ascending: true });
  if (error) throw error;
  const rows = (data ?? []) as Array<{
    slot: number;
    name: string;
    subtitle: string;
    image_url: string;
  }>;
  return rows.map((r) => ({
    slot: r.slot,
    name: r.name,
    subtitle: r.subtitle,
    imageUrl: r.image_url,
  }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let products: Array<{ slot: number; name: string; subtitle: string; imageUrl: string }> = [];
    let usedStaleCache = false;
    let refreshError: string | null = null;
    try {
      products = await refreshCache();
    } catch (err) {
      refreshError = (err as Error).message;
      const cached = await readExistingCache(supabase);
      if (cached.length >= 4) {
        products = cached.slice(0, 4);
        usedStaleCache = true;
      } else {
        throw err;
      }
    }

    if (!usedStaleCache) {
      const rows = products.map((p) => ({
        slot: p.slot,
        name: p.name,
        subtitle: p.subtitle,
        image_url: p.imageUrl,
        updated_at: new Date().toISOString(),
      }));

      const { error } = await supabase
        .from("sephora_popular_products_cache")
        .upsert(rows, { onConflict: "slot" });

      if (error) throw error;
    }

    return new Response(
      JSON.stringify({
        ok: true,
        stale_cache: usedStaleCache,
        refresh_error: refreshError,
        products,
      }),
      {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ ok: false, error: (err as Error).message }),
      {
        status: 200, // Return 200 so the client can fall back to cached results cleanly.
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
});

