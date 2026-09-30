#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-run --allow-env

import { parseArgs } from "jsr:@std/cli/parse-args";

const ARTWORK_COUNT = Number(Deno.env.get("ARTWORK_COUNT") ?? "10461");

const IMAGE_BASE_URL =
  "https://kraken66.blob.core.windows.net/images4000xn";
const METADATA_BASE_URL =
  "https://kraken66.blob.core.windows.net/tileinfo";

const home = Deno.env.get("HOME") ?? ".";
const cacheHome = Deno.env.get("XDG_CACHE_HOME") ?? `${home}/.cache`;

const cacheDirectory = `${cacheHome}/artworks`;
const imageDirectory = `${cacheDirectory}/images`;
const metadataDirectory = `${cacheDirectory}/metadata`;

const args = parseArgs(Deno.args, {
  boolean: [
    "print-image-path",
    "print-metadata-path",
    "print-paths",
    "set-wallpaper",
    "offline-only",
    "online-only",
    "offline-first",
    "online-first",
    "random",
  ],
  string: ["id"],
  alias: {
    h: "help",
  },
  default: {
    random: false,
  },
  negatable: false,
});

if (args.help) {
  printHelp();
  Deno.exit(0);
}

if (args._.length > 0) {
  throw new Error(`Unexpected argument(s): ${args._.join(" ")}`);
}

const policy = getCachePolicy(args);
const artworkId = getArtworkId(args);

const imagePath = `${imageDirectory}/${artworkId}.jpg`;
const metadataPath = `${metadataDirectory}/${artworkId}.json`;

const imageUrl = `${IMAGE_BASE_URL}/${artworkId}.jpg`;
const metadataUrl = `${METADATA_BASE_URL}/${artworkId}.json`;

await Deno.mkdir(imageDirectory, { recursive: true });
await Deno.mkdir(metadataDirectory, { recursive: true });

if (args["print-image-path"] || args["print-paths"]) {
  console.log(imagePath);
}

if (args["print-metadata-path"] || args["print-paths"]) {
  console.log(metadataPath);
}

// Ensure the image is available before trying to set it as wallpaper.
const resolvedImagePath = await ensureImage({
  policy,
  imagePath,
  imageUrl,
});

if (args["set-wallpaper"]) {
  await setWallpaper(resolvedImagePath);
  await notify(`Artwork #${artworkId}`, "Wallpaper changed");
}

// Metadata does not block changing the wallpaper. Start it after the image
// has been made available.
await ensureMetadata({
  policy,
  metadataPath,
  metadataUrl,
});

await notify(`Artwork #${artworkId} is ready`, "Artworks");

function getArtworkId(parsedArgs: Record<string, unknown>): number {
  const id = parsedArgs.id;

  if (id !== undefined && parsedArgs.random) {
    throw new Error("--id and --random cannot be used together");
  }

  if (id !== undefined) {
    const numericId = Number(id);

    if (
      !Number.isInteger(numericId) ||
      numericId < 1 ||
      numericId > ARTWORK_COUNT
    ) {
      throw new Error(
        `Artwork ID must be an integer between 1 and ${ARTWORK_COUNT}`,
      );
    }

    return numericId;
  }

  // Random selection is the default when no --id is supplied.
  return randomArtworkId(ARTWORK_COUNT);
}

type CachePolicy =
  | "offline-only"
  | "online-only"
  | "offline-first"
  | "online-first";

function getCachePolicy(
  parsedArgs: Record<string, unknown>,
): CachePolicy {
  const policies = [
    "offline-only",
    "online-only",
    "offline-first",
    "online-first",
  ].filter((name) => parsedArgs[name] === true);

  if (policies.length > 1) {
    throw new Error(
      `Only one cache policy may be selected: ${policies.join(", ")}`,
    );
  }

  // Online-first is the most useful default for a wallpaper script:
  // try to get a fresh copy, then fall back to the cache.
  return (policies[0] as CachePolicy | undefined) ?? "online-first";
}

function randomArtworkId(count: number): number {
  return Math.floor(Math.random() * count) + 1;
}

async function ensureImage(options: {
  policy: CachePolicy;
  imagePath: string;
  imageUrl: string;
}): Promise<string> {
  const { policy, imagePath, imageUrl } = options;
  const exists = await fileExists(imagePath);

  if (policy === "offline-only") {
    if (!exists) {
      throw new Error(
        `Image is not cached and --offline-only was specified: ${imagePath}`,
      );
    }

    return imagePath;
  }

  if (policy === "offline-first" && exists) {
    return imagePath;
  }

  if (policy === "online-only") {
    await downloadImage(imageUrl, imagePath);
    return imagePath;
  }

  if (policy === "online-first") {
    try {
      await downloadImage(imageUrl, imagePath);
      return imagePath;
    } catch (error) {
      if (exists) {
        console.warn(
          `Online image download failed; using cached image instead: ${
            error instanceof Error ? error.message : error
          }`,
        );
        return imagePath;
      }

      throw error;
    }
  }

  // offline-first with no cached image, or any other cache miss.
  await downloadImage(imageUrl, imagePath);
  return imagePath;
}

async function ensureMetadata(options: {
  policy: CachePolicy;
  metadataPath: string;
  metadataUrl: string;
}): Promise<string> {
  const { policy, metadataPath, metadataUrl } = options;
  const exists = await fileExists(metadataPath);

  if (policy === "offline-only") {
    if (!exists) {
      throw new Error(
        `Metadata is not cached and --offline-only was specified: ${metadataPath}`,
      );
    }

    return metadataPath;
  }

  if (policy === "offline-first" && exists) {
    return metadataPath;
  }

  if (policy === "online-only") {
    await downloadMetadata(metadataUrl, metadataPath);
    return metadataPath;
  }

  if (policy === "online-first") {
    try {
      await downloadMetadata(metadataUrl, metadataPath);
      return metadataPath;
    } catch (error) {
      if (exists) {
        console.warn(
          `Online metadata download failed; using cached metadata instead: ${
            error instanceof Error ? error.message : error
          }`,
        );
        return metadataPath;
      }

      throw error;
    }
  }

  await downloadMetadata(metadataUrl, metadataPath);
  return metadataPath;
}

async function downloadImage(
  url: string,
  destination: string,
): Promise<void> {
  console.error(`Downloading image: ${url}`);

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(
      `Image request failed: ${response.status} ${response.statusText}`,
    );
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  await atomicWrite(destination, bytes);
}

async function downloadMetadata(
  url: string,
  destination: string,
): Promise<void> {
  console.error(`Downloading metadata: ${url}`);

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(
      `Metadata request failed: ${response.status} ${response.statusText}`,
    );
  }

  const text = await response.text();

  // Validate before placing the metadata in the cache.
  JSON.parse(text);

  await atomicWrite(destination, text);
}

async function setWallpaper(imagePath: string): Promise<void> {
  // swaybg remains running and owns the wallpaper. Ignore the error when no
  // previous swaybg process exists.
  await new Deno.Command("pkill", {
    args: ["-x", "swaybg"],
    stdout: "null",
    stderr: "null",
  }).output();

  const command = new Deno.Command("swaybg", {
    args: ["--mode", "fill", "--image", imagePath],
    stdout: "null",
    stderr: "piped",
  });

  const process = command.spawn();

  // Detect immediate startup failures without waiting for swaybg to exit
  // during normal operation.
  setTimeout(async () => {
    const status = await process.status;

    if (!status.success) {
      console.error(`swaybg exited with status ${status.code}`);
    }
  }, 500);

  console.error(`Wallpaper set to ${imagePath}`);
}

async function notify(message: string, title: string): Promise<void> {
  try {
    await new Deno.Command("notify-send", {
      args: ["--app-name=Artworks", title, message],
      stdout: "null",
      stderr: "null",
    }).output();
  } catch {
    // Notifications are optional.
  }
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await Deno.stat(path);
    return true;
  } catch {
    return false;
  }
}

async function atomicWrite(
  destination: string,
  contents: string | Uint8Array,
): Promise<void> {
  const temporaryPath = `${destination}.${crypto.randomUUID()}.tmp`;

  try {
    if (typeof contents === "string") {
      await Deno.writeTextFile(temporaryPath, contents);
    } else {
      await Deno.writeFile(temporaryPath, contents);
    }

    await Deno.rename(temporaryPath, destination);
  } finally {
    await Deno.remove(temporaryPath).catch(() => undefined);
  }
}

function printHelp(): void {
  console.log(`Usage:
  artwork-wallpaper.ts [options]

Artwork selection:
  --random                  Select a random artwork. This is the default.
  --id <number>             Select a specific artwork ID.

Cache/network policy:
  --offline-only            Only use cached files; fail if missing.
  --online-only             Always download from the server.
  --offline-first           Use cache, downloading only when missing.
  --online-first            Prefer a download, falling back to cache.

Actions:
  --set-wallpaper           Set the wallpaper using swaybg.
  --print-image-path        Print the cached image path.
  --print-metadata-path     Print the cached metadata path.
  --print-paths             Print both paths.
  --help                    Show this help message.

Environment:
  ARTWORK_COUNT              Maximum artwork ID. Default: ${ARTWORK_COUNT}
  XDG_CACHE_HOME             Cache root. Default: ~/.cache
`);
}
