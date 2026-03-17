#!/usr/bin/env -S deno run --allow-net --allow-run --allow-read --allow-write --allow-env

import { join } from "https://deno.land/std@0.224.0/path/mod.ts";

/**
 * CONFIGURATION & OS DETECTION
 */
const DEFAULT_SEARCH = "https://duckduckgo.com/?q=";
const BANG_DATA_URL = "https://duckduckgo.com/bang.js";

function getOpener(): string {
  switch (Deno.build.os) {
    case "darwin":
      return "open";
    case "windows":
      return "explorer";
    default:
      return "xdg-open";
  }
}

interface Bang {
  t: string; // trigger
  u: string; // url template
}

/**
 * BANG LOGIC & CACHING
 */
async function getBangLookup(
  configDir: string,
): Promise<Record<string, string>> {
  const cachePath = join(configDir, "bangs.json");
  let data: Bang[] = [];

  try {
    const stats = await Deno.stat(cachePath);
    // Refresh cache if older than 24 hours
    const isOld = Date.now() - stats.mtime!.getTime() > 24 * 60 * 60 * 1000;
    if (isOld) throw new Error("Cache expired");

    data = JSON.parse(await Deno.readTextFile(cachePath));
  } catch {
    // Fetch and cache if missing or expired
    try {
      const res = await fetch(BANG_DATA_URL);
      data = await res.json();
      await Deno.writeTextFile(cachePath, JSON.stringify(data));
    } catch (e) {
      console.error("!!-- Failed to fetch bangs, using default search only.");
      return {};
    }
  }

  const lookup: Record<string, string> = {};
  data.forEach((entry) => {
    lookup[entry.t] = entry.u;
  });
  return lookup;
}

function resolveBang(input: string, lookup: Record<string, string>): string {
  const parts = input.split(/\s+/);
  let foundBangUrl = "";

  const query = parts.filter((word) => {
    // Check if word is a bang (e.g., !w, !g)
    const bangKey = word.startsWith("!") ? word.slice(1).toLowerCase() : null;
    if (bangKey && lookup[bangKey] && !foundBangUrl) {
      foundBangUrl = lookup[bangKey];
      return false; // Remove bang from the search query
    }
    return word !== "";
  }).join(" ");

  if (foundBangUrl) {
    return foundBangUrl.replace("{{{s}}}", encodeURIComponent(query));
  }
  return DEFAULT_SEARCH + encodeURIComponent(input);
}

/**
 * SUGGESTIONS (DuckDuckGo API)
 */
async function fetchSuggestions(searchString: string): Promise<string[]> {
  const url = `https://duckduckgo.com/ac/?q=${encodeURIComponent(searchString)
    }&type=list`;
  try {
    const res = await fetch(url);
    const data = await res.json();
    return data[1] || [];
  } catch {
    return [];
  }
}

async function main() {
  const home = Deno.env.get("HOME") || Deno.env.get("USERPROFILE") || "";
  const configDir = join(home, ".config", "rofi-web-search");

  // Ensure config directory exists for the bang cache
  try {
    await Deno.mkdir(configDir, { recursive: true });
  } catch { /* Directory might already exist */ }

  const lookup = await getBangLookup(configDir);
  const rawInput = Deno.args.join(" ").trim();

  // 1. Handle Suggestions
  if (rawInput.endsWith("!")) {
    const query = rawInput.slice(0, -1).trim();
    if (!query) {
      console.log("!!-- Type a query then '!' for suggestions");
      return;
    }
    const results = await fetchSuggestions(query);
    results.forEach((r) => console.log(r));
  } // 2. Handle Empty Input
  else if (rawInput === "") {
    console.log("!!-- Enter a search query");
    console.log("!!-- Add '!' at the end for suggestions");
    console.log("!!-- Use bangs (e.g., !gh, !w) to search specific sites");
    // ... (rest of the main function)
  } // 3. Execute Search
  else {
    const targetUrl = resolveBang(rawInput, lookup);
    const opener = getOpener();

    const command = new Deno.Command(opener, {
      args: [targetUrl],
      // Detach the pipes completely
      stdin: "null",
      stdout: "null",
      stderr: "null",
    });

    const child = command.spawn();

    // This is the magic line: it allows the Deno process to exit
    // even if the browser (child) is still running.
    child.unref();

    // Force an immediate exit so Rofi can close its window
    Deno.exit(0);
  }
}

main().catch(() => Deno.exit(1));
