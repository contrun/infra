#!/usr/bin/env python3

import sys
import argparse
import subprocess
from urllib.parse import quote

url = ''
parser = argparse.ArgumentParser(description='org protocol wrapper')
parser.add_argument('-p', '--protocol', help='protocol', default='capture')
parser.add_argument(
    '-t', '--template', help='template', nargs='?', default='i')

# args, unknown = parser.parse_known_args(['--foo', 'BAR', 'spam', 'test'])
args, unknown = parser.parse_known_args()
if len(unknown) % 2:
    print('must have even number of unknown arguments', file=sys.stderr)
    exit(1)
if not unknown:
    pairs = []
else:
    keys = [quote(unknown[i]) for i in range(len(unknown)) if not i % 2]
    values = [quote(unknown[i]) for i in range(len(unknown)) if i % 2]
    pairs = [(keys[i] + '=' + values[i]) for i in range(len(keys))]

pairs = ['template=' + args.template] + pairs
url = 'org-protocol://' + args.protocol + '?' + '&'.join(pairs)
# print(url)
subprocess.run(['emacsclient', '-n', '-c', url])
