#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["artscraper", "tqdm"]
# ///

import glob
import json

from artscraper import WikiArtScraper
from tqdm import tqdm

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
