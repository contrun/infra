local vertical_tabs = require "vertical_tabs"

leader1 = "<Mod1-x>"
leader2 = "<Mod1-c>"
leader3 = "<Mod1-v>"
leader4 = "<Mod1-s>"

-- Keybindings
local modes = require("modes")
modes.add_binds("normal", {
    -- Tabs
    {"<Mod1-t>t", "org todo.", function(w) org_capture(w, 't') end},
    {"<Mod1-tt>", "org todo.", function(w) org_capture(w, 't') end},
    {leader2 .. "t", "org todo.", function(w) org_capture(w, 't') end},
    {leader2 .. "c", "org capture.", function(w) org_capture(w, 'c') end},
    {leader2 .. "b", "org bookmark.", function(w) org_capture(w, 'b') end},
    {leader2 .. "w", "org wiki.", function(w) org_capture(w, 'b') end},
    {"K", "Go to previous tab.", function(w) w:prev_tab() end}, {
        "J", "Go to next tab (or `[count]` nth tab).",
        function(w, m) if not w:goto_tab(m.count) then w:next_tab() end end,
        {count = 0}
    }
})

modes.add_binds("ex-follow", {
    -- Yank element uri to open in an external application
    {
        "d",
        "Hint all links (as defined by the `follow.selectors.uri` selector) and set the primary selection to the matched elements URI, so that an external app can open it.",
        function(w)
            w:set_mode("follow", {
                prompt = "video",
                selector = "uri",
                evaluator = "uri",
                func = function(uri)
                    assert(type(uri) == "string")
                    uri = string.gsub(uri, " ", "%%20")
                    luakit.selection.primary = uri
                    if string.match(uri, "youtube") then
                        luakit.spawn(string.format(
                                         "mpv --ytdl-format 'best[height<=720]' '%s'",
                                         uri))
                        -- This also works
                        -- luakit.spawn(string.format("mpv --geometry=640x360 %s", uri ))
                        w:notify("trying to play file on mpv " .. uri)
                    elseif string.match(uri, "vimeo") then
                        luakit.spawn(string.format("mpv %s", uri))
                        w:notify("trying to play file on mpv " .. uri)
                    elseif string.match(uri, "vine") then
                        luakit.spawn(string.format("mpv %s", uri))
                        w:notify("trying to play file on mpv " .. uri)
                    elseif string.match(uri, "pdf" or "PDF") then
                        luakit.spawn(string.format(
                                         "openFileFromURL.sh %s zathura", uri))
                        w:notify("trying to read file via zathura " .. uri)
                    elseif string.match(uri, "jpg") then
                        luakit.spawn(string.format("feh -x %s", uri))
                        w:notify("file contains jpg " .. uri)
                    else
                        luakit.spawn(string.format("openFileFromURL.sh %s", uri))
                        w:notify("trying to read file via open " .. uri)
                    end
                end
            })
        end
    }
})

-- Commands
modes.add_cmds({
    {":org-todo, :ot", "org todo", function(w) org_capture(w, 't') end},
    {":org-wiki, :ow", "org wiki", function(w) org_capture(w, 'w') end},
    {":org-capture, :oc", "org capture", function(w) org_capture(w, 'c') end},
    {
        ":org-bookmark, :ob", "org store link",
        function(w) org_capture(w, 'b') end
    }

})

-- settings
local settings = require "settings"

settings.window.home_page = "about:blank"
settings.window.reuse_new_tab_pages = true
settings.window.load_etc_hosts = false
settings.vertical_tabs.sidebar_width = 200
settings.webview.enable_webgl = true
settings.webview.hardware_acceleration_policy = "always"
settings.webview.zoom_level = 150
settings.session.always_save = true
settings.on["youtube.com"].webview.enable_javascript = true
settings.on["youtube.com"].webview.enable_plugins = true

settings.window.search_engines.default =
    settings.window.search_engines.duckduckgo

settings.window.search_engines.alexa = "https://www.alexa.com/siteinfo/%s"
settings.window.search_engines.alluc = "https://www.alluc.ee/stream/%s"
settings.window.search_engines.amazon =
    "https://www.amazon.com/s?field-keywords=%s"
settings.window.search_engines.amo =
    "https://addons.mozilla.org/-/firefox/search?cat=all&q=%s"
settings.window.search_engines.arch =
    "https://wiki.archlinux.org/index.php/Special:Search?fulltext=Search&search=%s"
settings.window.search_engines.archive =
    "https://web.archive.org/web/*/https://%s"
settings.window.search_engines.archive_is = "https://archive.is/https://%s"
settings.window.search_engines.archlinux =
    "https://www.archlinux.org/packages/?q=%s"
settings.window.search_engines.archwiki =
    "https://wiki.archlinux.org/?search=%s"
settings.window.search_engines.arxiv = "https://arxiv.org/find/all/1/all:+%s"
settings.window.search_engines.aur =
    "https://aur.archlinux.org/packages.php?O=0&K=%s&do_Search=Go"
settings.window.search_engines.bing = "https://www.bing.com/search?q=%s"
settings.window.search_engines.britannica =
    "https://www.britannica.com/search?query=%s"
settings.window.search_engines.chocolatey =
    "https://chocolatey.org/packages?q=%s"
settings.window.search_engines.cnrtl = "https://www.cnrtl.fr/lexicographie/%s"
settings.window.search_engines.cpp =
    "https://en.cppreference.com/mwiki/index.php?search=%s"
settings.window.search_engines.devdocs = "https://devdocs.io/#q=%s"
settings.window.search_engines.ddg = "https://duckduckgo.com/?q=%s"
settings.window.search_engines.ddlw = "https://ddl-warez.in/?search=%s"
settings.window.search_engines.default =
    settings.window.search_engines.duckduckgo
settings.window.search_engines.doi = "https://doi.org/%s"
settings.window.search_engines.duckduckgo = "https://duckduckgo.com/?q=%s"
settings.window.search_engines.duden =
    "https://www.duden.de/suchen/dudenonline/%s"
settings.window.search_engines.ecosia = "https://ecosia.org/search.php?q=%s"
settings.window.search_engines.emacswiki =
    "https://duckduckgo.com/?q=site%3Aemacswiki.org+%s"
settings.window.search_engines.github =
    "https://github.com/search?type=Everything&repo=&langOverride=&start_value=1&q=%s"
settings.window.search_engines.goodreads =
    "https://www.goodreads.com/search?query=%s"
settings.window.search_engines.googlebooks =
    "https://www.google.com/search?tbm=bks&q=%s"
settings.window.search_engines.google =
    "https://www.google.com/search?ie=utf-8&oe=utf-8&q=%s"
settings.window.search_engines.google_images =
    "https://www.google.com/images?hl=en&source=hp&biw=1440&bih=795&gbv=2&aq=f&aqi=&aql=&oq=&q=%s"
settings.window.search_engines.google_maps =
    "https://www.google.com/maps/search/%s"
settings.window.search_engines.google_play =
    "https://play.google.com/store/search?c=apps&q=%s"
settings.window.search_engines.google_scholar =
    "https://scholar.google.com/scholar?q=%s"
settings.window.search_engines.google_translate =
    "https://translate.google.com/#auto|en|%s"
settings.window.search_engines.google_video =
    "https://www.google.com/search?q=TEST&tbm=vid%s"
settings.window.search_engines.greasyfork =
    "https://greasyfork.org/scripts?q=test%s"
settings.window.search_engines.gutenberg =
    "https://www.gutenberg.org/ebooks/search/?query=%s"
settings.window.search_engines.imdb = "https://www.imdb.com/find?s=all&q=%s"
settings.window.search_engines.larousse_fr_en =
    "https://www.larousse.fr/dictionnaires/francais-anglais/%s"
settings.window.search_engines.larousse =
    "https://www.larousse.fr/dictionnaires/francais/%s"
settings.window.search_engines.leo =
    "https://dict.leo.org/dictQuery/m-vocab/ende/de.html?searchLoc=0&lp=ende&lang=de&directN=0&search=%s"
settings.window.search_engines.libgen =
    "http://gen.lib.rus.ec/search.php?req=100&req=%s"
settings.window.search_engines.librivox =
    "https://librivox.org/search?search_form=advanced&q=%s"
settings.window.search_engines.manuals =
    "https://www.die.net/search/?sa=Search&ie=ISO-8859-1&cx=partner-pub-5823754184406795%3A54htp1rtx5u&cof=FORID%3A9&siteurl=www.die.net%2Fsearch%2F%3Fq%3DTEST%26sa%3DSearch#908&q=%s"
settings.window.search_engines.manpages =
    "https://manpages.ubuntu.com/cgi-bin/search.py?q=%s"
settings.window.search_engines.mathoverflow =
    "https://mathoverflow.net/search?q=%s"
settings.window.search_engines.mathscinet =
    "https://www.ams.org/mathscinet/search/publications.html?pg4=ALLF&s4=%s"
settings.window.search_engines.merriam_webster =
    "https://www.merriam-webster.com/dictionary/%s"
settings.window.search_engines.merriam_webster_thesaurus =
    "https://www.merriam-webster.com/thesaurus/%s"
settings.window.search_engines.metager =
    "https://metager.de/en/meta/meta.ger3?eingabe=%s"
settings.window.search_engines.mnemonic_dictionary =
    "https://www.mnemonicdictionary.com/word/%s"
settings.window.search_engines.mref =
    "https://mathscinet.ams.org/mathscinet-mref?ref=%s"
settings.window.search_engines.ncbi =
    "https://www.ncbi.nlm.nih.gov/gquery/?term=%s"
settings.window.search_engines.openlibrary =
    "https://www.openlibrary.org/search?q=%s"
settings.window.search_engines.openstreetmap =
    "https://nominatim.openstreetmap.org/search.php?q=%s"
settings.window.search_engines.opensubtitles =
    "https://www.opensubtitles.org/en/search2/moviename-%s"
settings.window.search_engines.oxford =
    "https://en.oxforddictionaries.com/definition/%s"
settings.window.search_engines.php =
    "https://php.net/manual-lookup.php?pattern=%s&scope=quickref"
settings.window.search_engines.pypi =
    "https://pypi.python.org/pypi?:action=search&term=%s"
settings.window.search_engines.qwant =
    "https://www.qwant.com/?client=opensearch&q=%s"
settings.window.search_engines.reddit = "https://www.reddit.com/search?q=%s"
settings.window.search_engines.science_willpowell_co =
    "https://science.willpowell.co.uk/?q=%s"
settings.window.search_engines.scihub = "https://sci-hub.tw/%s"
settings.window.search_engines.slickdeals =
    "https://slickdeals.net/newsearch.php?q=%s"
settings.window.search_engines.smzdm = "https://search.smzdm.com/?s=%s"
settings.window.search_engines.snopes = "https://www.snopes.com/?s=%s"
settings.window.search_engines.souyun =
    "https://sou-yun.com/QueryPoem.aspx?key=%s"
settings.window.search_engines.springerlink =
    "https://link.springer.com/search?query=%s"
settings.window.search_engines.stackoverflow =
    "https://stackoverflow.com/search?q=%s"
settings.window.search_engines.startpage =
    "https://startpage.com/do/metasearch.pl?query=%s"
settings.window.search_engines.suse =
    "https://en.opensuse.org/index.php?search=%s"
settings.window.search_engines.twitter = "https://twitter.com/search?q=%s"
settings.window.search_engines.vimeo = "https://vimeo.com/search?q=%s"
settings.window.search_engines.vim =
    "https://vim.wikia.com/wiki/Special:Search?search=%s"
settings.window.search_engines.wiki =
    "https://de.wikipedia.org/w/index.php?search=%s"
settings.window.search_engines.wikileaks = "https://search.wikileaks.org/?q=%s"
settings.window.search_engines.wikipedia_de =
    "https://de.wikipedia.org/wiki/Special:Search?search=%s"
settings.window.search_engines.wikipedia_en =
    "https://en.wikipedia.org/wiki/Special:Search?search=%s"
settings.window.search_engines.wikipedia_fr =
    "https://fr.wikipedia.org/wiki/Special:Search?search=%s"
settings.window.search_engines.wikipedia =
    "https://www.wikipedia.org/search-redirect.php?language=en&go=Go&search=%s"
settings.window.search_engines.wikipedia_zh =
    "https://zh.wikipedia.org/wiki/Special:Search?search=%s"
settings.window.search_engines.wolframalpha =
    "https://www.wolframalpha.com/input/?i=%s"
settings.window.search_engines.wordpress_plugins =
    "https://wordpress.org/extend/plugins/search.php?q=%s"
settings.window.search_engines.yahoo = "https://search.yahoo.com/search?p=%s"
settings.window.search_engines.yandex = "https://www.yandex.com/search/?text=%s"
settings.window.search_engines.youdao = "https://dict.youdao.com/search?q=%s"
settings.window.search_engines.youtube =
    "https://www.youtube.com/results?aq=f&oq=&search_query=%s"
settings.window.search_engines.zdic = "https://www.zdic.net/search/?q=%s"

soup.accept_policy = "no_third_party"

local editor = require "editor"
editor.editor_cmd = "urxvtc -e nvim {file} +{line}"

-- functions
------------------------------------------------------------
-- org.lua: Emacs org-mode integration for luakit
------------------------------------------------------------

function org_capture(w, template)
    local cmd = 'emacsclient'
    local sel = luakit.selection.primary or ""
    local title = w.view.title or ""
    local uri = w.view.uri or ""
    local args = '-n -c ' .. '\"org-protocol://capture?template=' .. template ..
                     '&url=' .. luakit.uri_encode(uri) .. '&title=' ..
                     luakit.uri_encode(title) .. '&body=' ..
                     luakit.uri_encode(sel) .. '\"'
    luakit.spawn(string.format("%s %s", cmd, args))
end

----------------------------------------------------------
-- vim: et:sw=4:ts=8:sts=4:tw=80
