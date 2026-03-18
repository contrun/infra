#!/usr/bin/env -S deno run --allow-net --allow-env --allow-write --allow-read

import { DOMParser, Element } from "jsr:@b-fuze/deno-dom";
import { Command } from "jsr:@cliffy/command";
import { Table } from "jsr:@cliffy/table";
import { colors } from "jsr:@cliffy/ansi/colors";
import { join } from "jsr:@std/path";

// --- Types ---
interface BookRecord {
  title: string;
  authors: string;
  lang: string;
  ext: string;
  size: string;
  source: string;
  link: string;
}

// --- Utilities ---
function sanitizeFilename(filename: string): string {
  return filename.replace(/[\\/:*?"<>|]/g, "_").trim().replace(/_+/g, "_") || "untitled";
}

// --- Scraper Logic ---
async function searchAnnas(
  query: string,
  baseUrl: string,
  langs: string | undefined,
  sort: string | undefined
): Promise<BookRecord[]> {
  const url = new URL(`${baseUrl}/search`);
  url.searchParams.set("q", query);
  if (sort) url.searchParams.set("sort", sort);
  if (langs) {
    langs.split(",").forEach(l => url.searchParams.append("lang", l.trim()));
  }

  const res = await fetch(url.toString(), {
    headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }
  });

  const html = await res.text();
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return [];

  const results: BookRecord[] = [];
  const rows = doc.querySelectorAll(".js-aarecord-list-outer .flex");

  for (const row of rows) {
    const el = row as Element;
    const titleTag = el.querySelector(".js-vim-focus");
    const linkTag = el.querySelector("a[href^='/md5/']");
    if (!titleTag || !linkTag) continue;

    const metaLine = el.querySelector(".text-gray-800")?.textContent || "";
    const parts = metaLine.split("·").map(p => p.trim());

    results.push({
      title: titleTag.textContent.trim(),
      authors: el.querySelector(".icon-\\[mdi--user-edit\\]")?.parentElement?.textContent.trim() || "Unknown",
      lang: parts[0] || "?",
      ext: parts[1] || "?",
      size: parts[2] || "?",
      source: parts[5] || "?",
      link: `${baseUrl}${linkTag.getAttribute("href")}`,
    });
  }
  return results;
}

async function downloadBook(md5Url: string, cookie?: string) {
  console.log(colors.dim(`Fetching download links from: ${md5Url}`));

  const headers: Record<string, string> = { "User-Agent": "Mozilla/5.0" };
  if (cookie) headers["Cookie"] = cookie;

  const res = await fetch(md5Url, { headers });
  const html = await res.text();
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error("Could not parse book page.");

  // Extract Title and Author for filename
  const title = doc.querySelector("div.text-3xl")?.textContent.trim() || "unknown_book";
  const author = doc.querySelector("div.italic")?.textContent.trim() || "unknown_author";

  // Find download links (prioritizing /fast_download or /get)
  const links = Array.from(doc.querySelectorAll("a"))
    .map(a => a.getAttribute("href") || "")
    .filter(href => href.includes("/fast_download") || href.includes("/get") || href.startsWith("http"));

  if (links.length === 0) throw new Error("No download links found on page.");

  // For simplicity, take the first available mirror
  let dlUrl = links[0];
  if (dlUrl.startsWith("/")) {
    const base = new URL(md5Url).origin;
    dlUrl = `${base}${dlUrl}`;
  }

  console.log(colors.yellow(`Downloading: ${dlUrl}`));
  const dlRes = await fetch(dlUrl, { headers });
  if (!dlRes.ok) throw new Error(`Download failed with status ${dlRes.status}`);

  const extension = dlUrl.includes(".epub") ? ".epub" : dlUrl.includes(".mobi") ? ".mobi" : ".pdf";
  const filename = sanitizeFilename(`${title} - ${author}${extension}`);
  const path = join(Deno.cwd(), filename);

  const file = await Deno.open(path, { write: true, create: true });
  await dlRes.body?.pipeTo(file.writable);

  console.log(colors.green(`✓ Saved to: ${filename}`));
}

// --- CLI Definition ---
const program = new Command()
  .name("annas-downloader")
  .version("1.1.0")
  .description("Search and download books from Anna's Archive")
  .option("-b, --base-url <url:string>", "Base URL for Anna's Archive", {
    default: "https://annas-archive.gd", // Updated default to a common mirror
    env: "ANNAS_BASE_URL",
    global: true,
  })
  .option("-c, --cookie <cookie:string>", "Cookie string for fast downloads", {
    env: "ANNAS_COOKIE",
    global: true,
  });

// 1. Search Subcommand
program.command("search <query:string>", "Search for books")
  .option("-l, --languages <langs:string>", "Comma separated language codes", { env: "LANGUAGES" })
  .option("-s, --sort <sort:string>", "Ordering/Sort criteria", { env: "ORDER_BY" })
  .action(async (options, query) => {
    const results = await searchAnnas(options.baseUrl, query, options.languages, options.sort);
    if (results.length === 0) {
      console.log(colors.red("No results found."));
      return;
    }

    new Table()
      .header([colors.bold("Title"), colors.bold("Author"), colors.bold("Format"), colors.bold("Size")])
      .body(results.map(r => [
        colors.cyan(r.title.length > 50 ? r.title.slice(0, 47) + "..." : r.title),
        r.authors.slice(0, 27),
        colors.green(r.ext),
        r.size
      ]))
      .padding(2).border(true).render();

    console.log(colors.dim(`\nTop Result: ${results[0].link}`));
  });

// 2. Download Subcommand
program.command("download <url:string>", "Download a book directly from an MD5 URL")
  .action(async (options, url) => {
    try {
      await downloadBook(url, options.cookie);
    } catch (err) {
      console.error(colors.red(`Error: ${err.message}`));
    }
  });

// 3. "I'm Feeling Lucky" Subcommand (Get)
program.command("get <query:string>", "Search and download the first result immediately")
  .option("-l, --languages <langs:string>", "Comma separated language codes")
  .action(async (options, query) => {
    console.log(colors.dim(`Searching and grabbing first result for: "${query}"...`));
    const results = await searchAnnas(query, options.baseUrl, options.languages, undefined);

    if (results.length === 0) {
      console.log(colors.red("No results found."));
      return;
    }

    console.log(colors.blue(`Found: ${results[0].title}`));
    try {
      await downloadBook(results[0].link, options.cookie);
    } catch (err) {
      console.error(colors.red(`Download failed: ${err.message}`));
    }
  });

await program.parse(Deno.args);
