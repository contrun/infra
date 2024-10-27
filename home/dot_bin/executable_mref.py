#!/usr/bin/env python3
import sys
import argparse
import queue
import threading
import requests
# from collections import OrderedDict
import pyperclip
from bs4 import BeautifulSoup

def get_info(type, ref):
    '''
    get information from mathscinet mref
    '''
    mref_url = 'https://mathscinet.ams.org/mathscinet-mref'
    dataTypes = {'mathscinet': 'mathscinet',
                 'bibtex': 'bibtex',
                 'amsrefs': 'amsrefs',
                 'link': 'link',
                 'url': 'bibtex',
                 }
    error_messages = {0: None,
                      1: 'generic requests error',
                      2: 'no matches found',
                      3: 'possible html structure changes',
                      }
    status = 0
    params = (('dataType', dataTypes[type]), ('ref', ref),)
    try:
        response = requests.get(mref_url, params=params)
        soup = BeautifulSoup(response.text, 'html.parser')
        trs = soup.table.find_all('tr')
        trs_texts = [tr.getText() for tr in trs]
        numf = 'No Unique Match Found'
        matched = '* Matched *'
        if numf in trs_texts:
            status = 2
            result = numf
        elif matched in trs_texts:
            index = trs_texts.index(matched)
            if type == 'link':
                # print(trs_texts[index+2])
                result = BeautifulSoup(trs_texts[index+2],
                                       'html.parser').a['href']
            elif type == 'url':
                bib = [" ".join(i.split()) for i in trs_texts[index+1].splitlines()]
                url = [i for i in bib if i.startswith('URL = ')][0]
                result = url.split('{')[1].split('}')[0]
            else:
                result = trs_texts[index+1]
        else:
            status = 3
            result = 'html structure may have changed'
        return [status, result, error_messages[status]]
    except requests.exceptions.RequestException as e:
        status = 1
        result = str(e)
        return [status, result, error_messages[status]]


def print_info(type, ref):
    result = get_info(type, ref)
    output = result[1]
    if result[0] == 0:
        file = sys.stdout
    else:
        file = sys.stderr
        output = 'unable to get ref\ntype\n' + output
    print(output, file=file)


def worker():
    while True:
        item = q.get()
        if item is None:
            break
        print_info(*item)
        q.task_done()


def main():
    parser = argparse.ArgumentParser(description='Get bibliography from ams mref')
    parser.add_argument('-b', '--bibtex', dest='types',
                        action='append_const', const='bibtex',
                        help='get bibtex, default if no other arguments')
    parser.add_argument('-m', '--mathscinet', dest='types',
                        action='append_const', const='mathscinet',
                        help='get APA format reference')
    parser.add_argument('-a', '--amsrefs', dest='types',
                        action='append_const', const='amsrefs',
                        help='get amsrefs')
    parser.add_argument('-l', '--link', dest='types',
                        action='append_const', const='link',
                        help='get link to mathematical review')
    parser.add_argument('-u', '--url', dest='types',
                        action='append_const', const='url',
                        help='get url of reference')
    parser.add_argument('-c', '--clipboard', action='store_true',
                        default=False, help='whether use system clipboard')
    parser.add_argument('terms', nargs='*', help='terms to search')
#     if not sys.argv[1:]:
#         args = vars(parser.parse_args(['-u', '-m', '-b', '-a', '-l',
#                                        'J. Cheeger and T. Colding, On the structure ' +
#                                        'of space  with Ricci curvature bounded below ' +
#                                        'I , J. Differential Geom. 46 (1997) 406–480.' +
#                                       ' MR1484888', ]))
#     else:
#         args = vars(parser.parse_args())
    args = vars(parser.parse_args())
    terms = args['terms']
    types = args['types'] if args['types'] else ['bibtex']
    if args['clipboard']:
        terms.append(pyperclip.paste())
    if not terms:
        print('\nSearch term missing. -h to see help', file=sys.stderr)
        exit(1)
    global q
    q = queue.Queue()
    threads = []
    num_worker_threads = 5
    for ref in terms:
        for type in types:
            q.put([type, ref])
            # t = threading.Thread(target=worker, args=(type, ref,))
            # threads.append(t)
            # t.start()
    for i in range(num_worker_threads):
        t = threading.Thread(target=worker)
        t.start()
        threads.append(t)
    # block until all tasks are done
    q.join()
    # stop workers
    for i in range(num_worker_threads):
        q.put(None)
    for t in threads:
        t.join()


if __name__ == "__main__":
    main()
