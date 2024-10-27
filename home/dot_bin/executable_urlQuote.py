#!/usr/bin/env python3

from urllib.parse import quote, unquote
import argparse

parser = argparse.ArgumentParser(description='url encoder/decoder',
        allow_abbrev=True)
parser.add_argument('-e', '--encode', help='encode url', action='store_true')
parser.add_argument('-d', '--decode', help='decode url', action='store_true')
parser.add_argument('url')

args = vars(parser.parse_args())

if args['decode']:
    print(unquote(args['url']))
else:
    print(quote(args['url']))
