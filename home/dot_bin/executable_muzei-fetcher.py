#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["artscraper", "requests", "tqdm"]
# ///

import glob
import json
import os

from artscraper import WikiArtScraper
import requests
from tqdm import tqdm


def fetch_txt_files():
    base_url = "https://storage.googleapis.com/muzeifeaturedart/archivemeta/"
    year = 2014
    month = 2
    while True:
        filename = f"{year}{month:02d}.txt"
        url = f"{base_url}{filename}"
        if not os.path.exists(filename):
            try:
                response = requests.get(url, timeout=15)
                if response.status_code == 200:
                    with open(filename, "wb") as f:
                        f.write(response.content)
                    print(f"Downloaded {filename}")
                elif response.status_code in (403, 404):
                    # End of available archives on server
                    break
                else:
                    print(f"Failed to fetch {filename}: HTTP {response.status_code}")
                    break
            except Exception as e:
                print(f"Error fetching {filename}: {e}")
                break

        month += 1
        if month > 12:
            month = 1
            year += 1


fetch_txt_files()

txt_files = glob.glob('./*.txt')

all_urls = set()
for file in txt_files:
    with open(file, 'r') as f:
        first_line = f.readline().strip('\n')
        l = json.loads(first_line)
        for a in l:
            u = a['details_url']
            u = u.replace('http', 'https')
            if u.startswith('https://www.wikiart.org'):
                all_urls.add(u)

fetched_urls = set()
metadata_files = glob.glob('./data/**/*.json')
for file in metadata_files:
    with open(file, 'r') as f:
        d = json.load(f)
        u = d['link']
        fetched_urls.add(u)

remaining_urls = all_urls - fetched_urls
with WikiArtScraper(output_dir="data") as scraper:
    for u in tqdm(remaining_urls):
        try:
            scraper.load_link(u)
            scraper.save_image()
            scraper.save_metadata()
        except Exception as e:
            print(f"failed to download {u}: {e}\n")

