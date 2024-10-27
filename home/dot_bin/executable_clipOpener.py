#!/usr/bin/env python3
import argparse
import sys
from subprocess import Popen, check_output
from collections import namedtuple
from urllib.parse import quote

'''
This script gets the content of xselection, then run some programs from
predefined templates. An example is that you may want to search some reference
information using mref from ams, then you may want to download the article
from sci-hub. This script makes the whole process painless (almost).
'''

if sys.platform.startswith('linux'):
    open = 'xdg-open'
elif sys.platform.startswith('freebsd'):
    open = 'xdg-open'
else:
    print('{} is not supported, as it does not have xselection.'.format(sys.platform))
    exit(1)

engine_template = namedtuple("engine", "name keywords program template")
engines = [
    engine_template('alexa', 'alexa', open,
                    'https://www.alexa.com/siteinfo/{}'),
    engine_template('alluc', 'alluc', open, 'https://www.alluc.ee/stream/{}'),
    engine_template('amazon', 'amazon', open,
                    'https://www.amazon.com/s?field-keywordss={}'),
    engine_template('addons.moilla.org', 'amo', open,
                    'https://addons.mozilla.org/-/firefox/search?cat=all&q={}'),
    engine_template('archive', 'archive a', open,
                    'https://web.archive.org/web/*/{}'),
    engine_template('archive_is', 'archive_is', open, 'https://archive.is/{}'),
    engine_template('archlinux packages', 'archlinux pac', open,
                    'https://www.archlinux.org/packages/?q={}'),
    engine_template('archwiki', 'archwiki aw', open,
                    'https://wiki.archlinux.org/index.php/Special:Search?fulltext=Search&search={}'),
    engine_template('arxiv', 'arxiv', open,
                    'https://arxiv.org/find/all/1/all:+{}'),
    engine_template('arch user repository', 'aur', open,
                    'https://aur.archlinux.org/packages.php?O=0&&do_Search=go&K={}'),
    engine_template('bing', 'bing', open, 'https://www.bing.com/search?q={}'),
    engine_template('britannica', 'britannica', open,
                    'https://www.britannica.com/search?query={}'),
    engine_template('chocolatey', 'chocolatey', open,
                    'https://chocolatey.org/packages?q={}'),
    engine_template('cnrtl', 'cnrtl', open,
                    'https://www.cnrtl.fr/lexicographie/{}'),
    engine_template('cpp', 'cpp', open,
                    'https://en.cppreference.com/mwiki/index.php?search={}'),
    engine_template('devdocs', 'devdocs', open, 'https://devdocs.io/#q={}'),
    engine_template('ddlw', 'ddlw', open, 'https://ddl-warez.in/?search={}'),
    engine_template('doi', 'doi', open, 'https://doi.org/{}'),
    engine_template('duckduckgo', 'duckduckgo ddg d',
                    open, 'https://duckduckgo.com/?q={}'),
    engine_template('duden', 'duden', open,
                    'https://www.duden.de/suchen/dudenonline/{}'),
    engine_template('ecosia', 'ecosia', open,
                    'https://ecosia.org/search.php?q={}'),
    engine_template('emacswiki', 'emacswiki ew', open,
                    'https://duckduckgo.com/?q=site%3Aemacswiki.org+{}'),
    engine_template('github', 'github gh', open,
                    'https://github.com/search?type=Everything&repo=&langOverride=&start_value=1&q={}'),
    engine_template('goodreads', 'goodreads b', open,
                    'https://www.goodreads.com/search?query={}'),
    engine_template('googlebooks', 'googlebooks', open,
                    'https://www.google.com/search?tbm=bks&q={}'),
    engine_template('google', 'google g', open,
                    'https://www.google.com/search?ie=utf-8&oe=utf-8&q={}'),
    engine_template('google_images', 'google_images', open,
                    'https://www.google.com/images?hl=en&source=hp&biw=1440&bih=795&gbv=2&aq=f&aqi=&aql=&oq=&q={}'),
    engine_template('google_maps', 'google_maps', open,
                    'https://www.google.com/maps/search/{}'),
    engine_template('google_play', 'google_play', open,
                    'https://play.google.com/store/search?c=apps&q={}'),
    engine_template('google_scholar', 'google_scholar', open,
                    'https://scholar.google.com/scholar?q={}'),
    engine_template('google_translate', 'google_translate', open,
                    'https://translate.google.com/#auto|en|{}'),
    engine_template('google_video', 'google_video', open,
                    'https://www.google.com/search?q=TEST&tbm=vid{}'),
    engine_template('greasyfork', 'greasyfork', open,
                    'https://greasyfork.org/scripts?q=test{}'),
    engine_template('gutenberg', 'gutenberg', open,
                    'https://www.gutenberg.org/ebooks/search/?query={}'),
    engine_template('imdb', 'imdb', open,
                    'https://www.imdb.com/find?s=all&q={}'),
    engine_template('larousse_fr_en', 'larousse_fr_en', open,
                    'https://www.larousse.fr/dictionnaires/francais-anglais/{}'),
    engine_template('larousse', 'larousse', open,
                    'https://www.larousse.fr/dictionnaires/francais/{}'),
    engine_template('leo', 'leo', open,
                    'https://dict.leo.org/dictQuery/m-vocab/ende/de.html?searchLoc=0&lp=ende&lang=de&directN=0&search={}'),
    engine_template('library genesis', 'libgen library_genesis l',
                    open, 'http://gen.lib.rus.ec/search.php?res=100&req={}'),
    engine_template('librivox', 'librivox', open,
                    'https://librivox.org/search?search_form=advanced&q={}'),
    engine_template('manual', 'manual', open,
                    'https://manned.org/browse/search?q={}'),
    engine_template('manuals', 'manuals', open,
                    'https://www.die.net/search/?sa=Search&ie=ISO-8859-1&cx=partner-pub-5823754184406795%3A54htp1rtx5u&cof=FORID%3A9&siteurl=www.die.net%2Fsearch%2F%3Fq%3DTEST%26sa%3DSearch#908&q={}'),
    engine_template('manpages', 'manpages man', open,
                    'https://manpages.ubuntu.com/cgi-bin/search.py?q={}'),
    engine_template('mathoverflow', 'mathoverflow mof', open,
                    'https://mathoverflow.net/search?q={}'),
    engine_template('mathscinet', 'mathscinet msc m', open,
                    'https://www.ams.org/mathscinet/search/publications.html?pg4=ALLF&s4={}'),
    engine_template('merriam_webster', 'merriam_webster mw',
                    open, 'https://www.merriam-webster.com/dictionary/{}'),
    engine_template('merriam_webster_thesaurus', 'merriam_webster_thesaurus mwt',
                    open, 'https://www.merriam-webster.com/thesaurus/{}'),
    engine_template('metager', 'metager', open,
                    'https://metager.de/en/meta/meta.ger3?eingabe={}'),
    engine_template('mnemonic_dictionary', 'mnemonic_dictionary md',
                    open, 'https://www.mnemonicdictionary.com/word/{}'),
    engine_template('mref', 'mref r', open,
                    'https://mathscinet.ams.org/mathscinet-mref?ref={}'),
    engine_template('ncbi', 'ncbi', open,
                    'https://www.ncbi.nlm.nih.gov/gquery/?term={}'),
    engine_template('openlibrary', 'openlibrary ol', open,
                    'https://www.openlibrary.org/search?q={}'),
    engine_template('openstreetmap', 'openstreetmap', open,
                    'https://nominatim.openstreetmap.org/search.php?q={}'),
    engine_template('opensubtitles', 'opensubtitles os', open,
                    'https://www.opensubtitles.org/en/search2/moviename-{}'),
    engine_template('oxford', 'oxford', open,
                    'https://en.oxforddictionaries.com/definition/{}'),
    engine_template('php', 'php', open,
                    'https://php.net/manual-lookup.php?scope=quickref&pattern={}'),
    engine_template('python 3', 'python', open,
                    'https://docs.python.org/3/search.html?q={}'),
    engine_template('python 2', 'python2', open,
                    'https://docs.python.org/2/search.html?q={}'),
    engine_template('pypi', 'pypi', open,
                    'https://pypi.python.org/pypi?:action=search&term={}'),
    engine_template('qwant', 'qwant', open,
                    'https://www.qwant.com/?client=opensearch&q={}'),
    engine_template('reddit', 'reddit', open,
                    'https://www.reddit.com/search?q={}'),
    engine_template('science_willpowell_co', 'science_willpowell_co',
                    open, 'https://science.willpowell.co.uk/?q={}'),
    engine_template('scihub', 'scihub s', open, 'https://sci-hub.tw/{}'),
    engine_template('slickdeals', 'slickdeals', open,
                    'https://slickdeals.net/newsearch.php?q={}'),
    engine_template('smzdm', 'smzdm', open, 'https://search.smzdm.com/?s={}'),
    engine_template('snopes', 'snopes', open, 'https://www.snopes.com/?s={}'),
    engine_template('souyun', 'souyun', open,
                    'https://sou-yun.com/QueryPoem.aspx?key={}'),
    engine_template('springerlink', 'springerlink', open,
                    'https://link.springer.com/search?query={}'),
    engine_template('stackoverflow', 'stackoverflow f', open,
                    'https://stackoverflow.com/search?q={}'),
    engine_template('startpage', 'startpage', open,
                    'https://startpage.com/do/metasearch.pl?query={}'),
    engine_template('opensuse', 'opensuse suse', open,
                    'https://en.opensuse.org/index.php?search={}'),
    engine_template('twitter', 'twitter', open,
                    'https://twitter.com/search?q={}'),
    engine_template('vimeo', 'vimeo', open, 'https://vimeo.com/search?q={}'),
    engine_template('vim', 'vim', open,
                    'https://vim.wikia.com/wiki/Special:Search?search={}'),
    engine_template('wikileaks', 'wikileaks', open,
                    'https://search.wikileaks.org/?q={}'),
    engine_template('wikipedia_de', 'wikipedia_de', open,
                    'https://de.wikipedia.org/wiki/Special:Search?search={}'),
    engine_template('wikipedia_en', 'wikipedia_en', open,
                    'https://en.wikipedia.org/wiki/Special:Search?search={}'),
    engine_template('wikipedia_fr', 'wikipedia_fr', open,
                    'https://fr.wikipedia.org/wiki/Special:Search?search={}'),
    engine_template('wikipedia', 'wikipedia', open,
                    'https://www.wikipedia.org/search-redirect.php?language=en&go=Go&search={}'),
    engine_template('wikiwand', 'wikiwand w', open,
                    'https://www.wikiwand.com/en/{}'),
    engine_template('wikipedia_zh', 'wikipedia_zh', open,
                    'https://zh.wikipedia.org/wiki/Special:Search?search={}'),
    engine_template('wolfram alpha', 'wolframalpha alpha wa',
                    open, 'https://www.wolframalpha.com/input/?i={}'),
    engine_template('wordpress_plugins', 'wordpress_plugins', open,
                    'https://wordpress.org/extend/plugins/search.php?q={}'),
    engine_template('yahoo', 'yahoo', open,
                    'https://search.yahoo.com/search?p={}'),
    engine_template('yandex', 'yandex', open,
                    'https://www.yandex.com/search/?text={}'),
    engine_template('youdao', 'youdao', open,
                    'https://dict.youdao.com/search?q={}'),
    engine_template('youtube', 'youtube', open,
                    'https://www.youtube.com/results?aq=f&oq=&search_query={}'),
    engine_template('zdic', 'zdic', open, 'http://www.zdic.net/search/?q={}'),
    engine_template('open', 'open o', open, '{}'),
    engine_template('zeal', 'zeal z', 'zeal', '{}'),
    engine_template('mpv', 'mpv', 'mpv', '{}'),
    engine_template('goldendict', 'goldendict c', 'goldendict', '{}'),
    engine_template(
        'nvim', 'nvim n', 'file="/tmp/clip-$(date +"%y%m%d%H%M%S")"; xclip -o -selection {} > "$file"; urxvtc -title "floating nvim $file" -e nvim "$file"', ''),
    engine_template('emacs', 'emacs e',
                    'file="/tmp/clip-$(date +"%y%m%d%H%M%S")"; xclip -o -selection {} > "$file"; emacsclient -nc "$file"', ''),
]

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--get_clipboard', action="store_true")
    for engine in engines:
        keywords_list = engine.keywords.strip().split()
        short_options = ['-{}'.format(i) for i in keywords_list if len(i) == 1]
        long_options = ['--{}'.format(i) for i in keywords_list if len(i) > 1]
        options = short_options + long_options
        parser.add_argument(*options, action="store_true")
    args = vars(parser.parse_args())

    # do not wait for subprocess to exit
    # https://stackoverflow.com/questions/3516007/run-process-and-dont-wait
    popen_args = {'stdin': None, 'stdout': None,
                  'stderr': None, 'close_fds': True}
    selection = 'clipboard' if args['get_clipboard'] else 'primary'
    content = check_output(["xclip", "-o", "-selection", selection])
    content = content.decode('utf-8').strip()

    for engine in engines:
        if args[engine.keywords.strip().split()[0]]:
            if engine.template:
                if engine.template.startswith('http'):
                    content = engine.template.format(quote(content))
                else:
                    content = engine.template.format(content)
                Popen(engine.program.split() + [content], **popen_args)
            else:
                Popen(engine.program.format(selection),
                      shell=True, **popen_args)
