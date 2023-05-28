#!/usr/bin/env python

import sys
import os

secret = os.environ['ANSIBLE_PASSWORD']

def main():
    sys.stdout.write('%s\n' % secret)
    sys.exit(0)

if __name__ == '__main__':
    main()
