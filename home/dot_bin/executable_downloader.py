#!/usr/bin/env python3

import sys
import argparse
import os
import shutil
import subprocess
from collections import namedtuple
from shlex import quote

FILE = '/tmp/downloader.log'
NOTIFICATION = 'notifications.sh'


def remove_it(v):
    """used as transform_dict value to remove useless arguments"""
    return v, None


def convert_to_list(v):
    return v if isinstance(v, list) else [v]


class Downloader:
    '''
    Base class for the download programs. You may use transform_dict to
    transform arguments into a form which this program recongnize. The key of
    transform_dict is the argument name, while its value is a function which
    accept the argument option and returns a two-element tuple. The first
    element of the tuple is the transfomed argument name, and the second
    element is the transformed argument option.
    '''
    name = ''
    cmd_prefix = []  # executable prefix
    cmd_args = []  # store parsed arguments
    cmd = []  # store the whole command
    result = []  # execution result
    default_args = {}  # default arguments
    transform_dict = {}  # transform arguments to a desirable form

    def __init__(self,
                 args: dict,
                 default_args: dict = {},
                 cmd_prefix: list = []):
        if cmd_prefix:
            self.cmd_prefix = cmd_prefix
        url = args.pop('url', '')
        if url == '':
            raise ValueError('url not provided')
        self.args = args
        self.default_args = {**self.default_args, **default_args}
        self.args = self.transform_args(self.args, self.transform_dict)
        self.args = {**self.default_args, **self.args}
        self.cmd_args = self.get_cmd_args(self.args)
        self.cmd = self.cmd_prefix + self.cmd_args + [url]

    def __repr__(self):
        return ' '.join([quote(i) for i in self.cmd])

    @staticmethod
    def get_cmd_args(args: dict) -> list:
        l = []
        for k, v in args.items():
            prefix = '-' if len(k) == 1 else '--'
            arg = prefix + k
            if isinstance(v, list):
                for s in v:
                    l.append(arg)
                    l.append(str(s))
            else:
                l.append(arg)
                l.append(str(v))
        return l

    @staticmethod
    def transform_args(args: dict, transform_dict: dict) -> dict:
        args = {k: v for k, v in args.items() if v is not None}
        if not transform_dict or not args:
            return args
        ret = {}
        for k, v in args.items():
            f = transform_dict.get(k)
            if callable(f):
                r1, r2 = f(v)
                if isinstance(r2, list):
                    r2.extend(ret.get(r1, []))
                ret = {**ret, **{r1: r2}}
            elif f:
                ret = {**ret, **{k: v}}
        return {k: v for k, v in ret.items() if v is not None}

    def exec(self):
        """
        execute the command, return title and details for notification
        """
        p = subprocess.Popen(
            self.cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=-1)
        output, error = p.communicate()
        if p.returncode == 0:
            self.result = ['successfully ran ' + self.name, output.decode()]
        else:
            self.result = [
                'failed to run {}: {}'.format(self.name, p.returncode),
                error.decode() + output.decode()
            ]

    def notify(self):
        subprocess.call(
            '{} {} {}'.format(
                quote(NOTIFICATION), quote(self.result[1]),
                quote(self.result[0])),
            shell=True)


class Aria2rpc(Downloader):
    '''
    Class for aria2rpc. /usr/share/doc/aria2/xmlrpc/aria2rpc should come with
    aria2.
    '''
    name = 'aria2rpc'
    cmd_prefix = ['ruby', '/usr/share/doc/aria2/xmlrpc/aria2rpc', 'addUri']
    p = shutil.which('aria2rpc')
    if p:
        cmd_prefix = [p, 'addUri']
    transform_dict = {
        'comment': remove_it,
        'folder': remove_it,
        'post': remove_it,
        'rawpost': remove_it,
        'ulist': remove_it,
        'ufile': remove_it,
        'cfile': remove_it,
        'ua': (lambda x: ['user-agent', x]),
        'fname': (lambda x: ['out', x]),
        'headers': (lambda x: ['header', convert_to_list(x)]),
        'cookie':
        (lambda x: ['header', convert_to_list('Cookie: ' + x)]),
        'referer':
        (lambda x: ['header', convert_to_list('Referer: ' + x)]),
    }

    def __init__(self, args, default_args={}):
        super().__init__(args, default_args)


class Aria2c(Downloader):
    '''
    Class for aria2rpc. /usr/share/doc/aria2/xmlrpc/aria2rpc should come with
    aria2.
    '''

    name = 'aria2c'
    cmd_prefix = ['aria2c']
    transform_dict = {
        'comment': remove_it,
        'folder': remove_it,
        'post': remove_it,
        'rawpost': remove_it,
        'ulist': remove_it,
        'ufile': remove_it,
        'cfile': remove_it,
        'ua': (lambda x: ['user-agent', x]),
        'fname': (lambda x: ['out', x]),
        'headers': (lambda x: ['header', convert_to_list(x)]),
        'cookie':
        (lambda x: ['header', convert_to_list('Cookie: ' + x)]),
        'referer':
        (lambda x: ['header', convert_to_list('Referer: ' + x)]),
    }

    def __init__(self, args, default_args={}):
        super().__init__(args, default_args)


class Mpv(Downloader):
    '''
    Class for mpv.
    '''

    name = 'mpv'
    cmd_prefix = ['mpv']
    transform_dict = {
        'comment': remove_it,
        'folder': remove_it,
        'post': remove_it,
        'rawpost': remove_it,
        'ulist': remove_it,
        'ufile': remove_it,
        'cfile': remove_it,
        'ua': remove_it,
        'fname': (lambda x: ['title', x]),
        'headers': (lambda x: ['http-header-fields', convert_to_list(x)]),
        'cookie': (lambda x: ['http-header-fields', convert_to_list('Cookie: ' + x)]),
        'referer': (lambda x: ['http-header-fields', convert_to_list('Referer: ' + x)]),
    }

    def __init__(self, args, default_args={}):
        super().__init__(args, default_args)


def get_aria2rpc_options(index=0):
    template = namedtuple("template",
                          ("name", "server", "port", "secret", "all_proxy"))
    server = os.environ.get('server', 'localhost')

    port = os.environ.get('port', 6800)
    token = os.environ.get('token', 'token_nekot')
    proxy = os.environ.get('http_proxy', '127.0.0.1:8118')
    router = 'router.ddns.yihuo.men'
    remote = 'aria2.ddns.yihuo.men'

    aria2rpc_opts = [
        template('local proxy', server, port, token, proxy),
        template('local no proxy', server, port, token, ''),
        template('router proxy', router, port, token, proxy),
        template('router no proxy', router, port, token, ''),
        template('remote proxy', remote, port, token, proxy),
        template('remote no proxy', remote, port, token, ''),
    ]
    options = aria2rpc_opts[index]._asdict()
    options.pop('name', None)
    p = options.pop('all_proxy', None)
    if p is not None:
        options['all-proxy'] = p

    # ensure aria2c daemon is running
    if options['server'] in ('localhost', '127.0.0.1'):
        os.system('pgrep aria2c || aria2c -D --rpc-secret ' + token)

    return options


def get_aria2c_options(index=0):
    proxy = os.environ.get('http_proxy', '127.0.0.1:8118')
    aria2c_opts = [{'all-proxy': proxy}, {'all-proxy': ''}, {}]
    return aria2c_opts[index]


def get_mpv_options(index=0):
    default_proxy = 'http://127.0.0.1:8118'
    proxy = os.environ.get('http_proxy', default_proxy)
    aria2c_opts = [{'http-proxy': proxy}, {'http-proxy': ''}, {}]
    option = aria2c_opts[index]
    if option.get('http-proxy') != '':
        os.environ['http_proxy'] = proxy
    return {}


def get_backend(name, option, args):
    d = {
        'aria2rpc': [get_aria2rpc_options, Aria2rpc],
        'aria2c': [get_aria2c_options, Aria2c],
        'mpv': [get_mpv_options, Mpv],
    }
    try:
        [r1, r2] = d[name]
        return r2(args, r1(option))
    except IndexError as e:
        raise ValueError('unsupported backend {}'.format(name))


def parse_args():
    parser = argparse.ArgumentParser(description='downloader wrapper')
    parser.add_argument('url', metavar='url', help='url to download')
    parser.add_argument(
        '-b', '--backend', help='backend downloader', default='aria2rpc')
    parser.add_argument(
        '--bo',
        '--backend-option',
        help='backend option',
        dest='backend_option',
        type=int,
        default=0)
    parser.add_argument(
        '--comment',
        help='comment',
    )
    parser.add_argument(
        '--referer',
        help='referer URL',
    )
    parser.add_argument(
        '--cookie',
        help='cookie',
    )
    parser.add_argument(
        '--folder',
        help='download folder',
    )
    parser.add_argument(
        '--fname',
        help='file name',
    )
    parser.add_argument(
        '--headers',
        nargs='*',
        help='HTTP headers',
    )
    parser.add_argument(
        '--post',
        help='post data',
    )
    parser.add_argument(
        '--rawpost',
        help='raw post data',
    )
    parser.add_argument(
        '--ulist',
        help='URL list',
    )
    parser.add_argument(
        '--ufile',
        help='URL file',
    )
    parser.add_argument(
        '--cfile',
        help='cookies file',
    )
    parser.add_argument(
        '--userpass',
        help='HTTP username password',
    )
    parser.add_argument('--ua', help='Useragent')
    parser.add_argument(
        '--dryrun',
        action='store_true',
    )
    parser.add_argument(
        '--no-notification',
        action='store_true',
    )

    # test_args = [
    #     "-b", "aria2c", "--backend-option", "0", "--comment", "GET",
    #     "--referer",
    #     "http://libgen.io/ads.php?md5=A1E5BB7E56CAB2135BC9CE4424445203",
    #     "--cookie", "lg_topic=libgen;, libgen_get_key=IN9KIT57EFA3HMG9;, ",
    #     "--folder", "/home/e/Downloads", "--fname", "my simple test.pdf",
    #     "--ulist",
    #     "http://libgen.io/get.php?md5=A1E5BB7E56CAB2135BC9CE4424445203&key=IN9KIT57EFA3HMG9",
    #     "--headers", "My superb header",
    #     "--ufile", "/tmp/flashgot.im0nx8ya.default/flashgot-5.fgt", "--cfile",
    #     "/tmp/flashgot.im0nx8ya.default/cookies-5", "--ua",
    #     "Mozilla/5.0, (X11;, Linux, x86_64;, rv:52.9), Gecko/20100101, Goanna/3.4, Firefox/52.9, PaleMoon/27.6.1",
    #     "http://libgen.io/get.php?md5=A1E5BB7E56CAB2135BC9CE4424445203&key=IN9KIT57EFA3HMG9"
    # ]
    # args = vars(parser.parse_args(test_args))
    # flashgot options -b aria2rpc --bo 1 [--comment COMMENT] [--referer REFERER] [--cookie COOKIE] [--folder FOLDER] [--fname FNAME] [--headers HEADERS] [--post POST] [--rawpost RAWPOST] [--ulist ULIST] [--ufile UFILE] [--cfile CFILE] [--userpass USERPASS] [--ua UA] [URL]
    args = vars(parser.parse_args())
    return args


def main():
    original_args = ' '.join([quote(i) for i in sys.argv])
    print(original_args)
    with open(FILE, 'a') as f:
        print(original_args + '\n', file=f)
    args = parse_args()
    dryrun = args.pop('dryrun')
    no_notification = args.pop('no-notification', False)
    backend = args.pop('backend', 'aria2c')
    backend_option = args.pop('backend_option', 0)
    d = get_backend(backend, backend_option, args)
    print(d)
    with open(FILE, 'a') as f:
        print(str(d) + '\n', file=f)
    if not dryrun:
        d.exec()
        if not no_notification:
            d.notify()


if __name__ == '__main__':
    main()
