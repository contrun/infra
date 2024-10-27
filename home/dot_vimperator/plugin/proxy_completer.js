(function () {

    function parseHTML(aHTMLString){ // {{{
        var html = document.implementation.createDocument(
            "http://www.w3.org/1999/xhtml", "html", null),
        body = document.createElementNS("http://www.w3.org/1999/xhtml", "body");
        html.documentElement.appendChild(body);
        body.appendChild(Components.classes["@mozilla.org/feed-unescapehtml;1"]
            .getService(Components.interfaces.nsIScriptableUnescapeHTML)
            .parseFragment(aHTMLString, false, null, body));
        return body;
    } // }}}


    var Proxy = function () { // {{{
        this.load();
    }; // }}}

    Proxy.prototype.load = function () { // {{{
        this.type = options.getPref("network.proxy.type");
        this.host = options.getPref("network.proxy.http");
        this.port = options.getPref("network.proxy.http_port");
    }; // }}}

    Proxy.prototype.save = function (value) { // {{{
        var s2n = {
            'none': 0,
            'pac': 2,
            'auto-detect': 4,
            'system': 5
        };
        if (typeof s2n[value] !== "undefined") {
            options.setPref("network.proxy.type", s2n[value]);
            options.setPref("network.proxy.http", '');
            options.setPref("network.proxy.http_port", 0);
        } else {
            var [host, port] = value.split(":");
            options.setPref("network.proxy.type", 1);
            options.setPref("network.proxy.http", host);
            options.setPref("network.proxy.http_port", parseInt(port));
        }
        this.load();
    }; // }}}

    Proxy.prototype.echo = function () { // {{{
        if (this.type === 1) {
            liberator.echo("current setting = " + this.host + ":" + this.port);
        } else {
            var n2s = {
                0: 'none',
                2: 'pac',
                4: 'auto-detect',
                5: 'system'
            };
            liberator.echo("current setting = " + n2s[this.type]);
        }
    }; // }}}


    var CyberSyndromePlr = function () { // {{{
    } // }}}

    CyberSyndromePlr.prototype.getSourceURL = function () { // {{{
        return "http://www.cybersyndrome.net/plr.html";
    } // }}}

    CyberSyndromePlr.prototype.parse = function (htmlDoc) { // {{{
        var proxylist = new Array();
        var proxytype = {
            'A': 'A (anon, hidden)',
            'B': 'B (anon, visible)',
            'C': 'C (anon, lying)',
            'D': 'D (non-anon, leaking)'
        };
        var items = htmlDoc.getElementsByTagName("tr");
        for (var i = 1; i < Math.min(101, items.length); i++) {
            var tds = items[i].childNodes;
            var host = tds[1].textContent;
            var type = tds[3].textContent;
            var country = tds[4].textContent;
            proxylist.push([host, country + ": " + proxytype[type]]);
        }
        return proxylist;
    } // }}}


    var CyberSyndromePla5 = function () { // {{{
    } // }}}

    CyberSyndromePla5.prototype.getSourceURL = function () { // {{{
        return "http://www.cybersyndrome.net/pla5.html";
    } // }}}

    CyberSyndromePla5.prototype.parse = function (htmlDoc) { // {{{
        var proxylist = new Array();
        var proxytype = {
            'A': 'A (anon, hidden)',
            'B': 'B (anon, visible)',
            'C': 'C (anon, lying)',
            'D': 'D (non-anon, leaking)'
        };
        var items = htmlDoc.getElementsByTagName("li");
        for (var i = 0; i < Math.min(100, items.length); i++) {
            var a = items[i].firstChild;
            if ((a.tagName === "a" || a.tagName === "A") &&
                 a.textContent && a.title && a.className) {
                var host = a.textContent;
                var country = a.title;
                var type = a.className;
                proxylist.push([host, country + ": " + proxytype[type]]);
            }
        }
        return proxylist;
    } // }}}


    var Completer = function (source) { // {{{
        this.proxylist = [];
        this.source = source;
    }; // }}}

    Completer.prototype.communicate = function (onFinish) { // {{{
        var url = this.source.getSourceURL();
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    this.proxylist = this.source.parse(parseHTML(xhr.responseText));
                } else {
                    liberator.echoerr("communication failure: " + xhr.statusText);
                }
                onFinish();
            }
        }.bind(this);
        xhr.open("GET", url, true);
        xhr.send();
    }; // }}}

    Completer.prototype.getSuggestions = function (args) { // {{{
        var suggestions = [
            ['none', 'no proxy'],
            ['pac', 'proxy auto-configuration (PAC)'],
            ['auto-detect', 'auto-detect proxy settings'],
            ['system', 'system proxy settings']
        ];
        Array.prototype.push.apply(suggestions, this.proxylist);
        function filterFunc(command) {
            return command[0].indexOf(args) === 0 ||
                   command[1].indexOf(args) >= 0;
        }
        return suggestions.filter(filterFunc);
    }; // }}}


    commands.addUserCommand(["csproxy"], "set or get proxy setting", // {{{
        function (args) {
            var proxy = new Proxy();
            if (args.length > 0) {
                proxy.save(args[0]);
            }
            proxy.echo();
        },
        {
            completer: function (context, args) {
                var completer = new Completer(new CyberSyndromePlr());
                context.incomplete = true;
                context.title = ['Proxy'];
                context.completions = completer.getSuggestions(args);
                context.filters = [];
                context.compare = void 0;
                completer.communicate(function () {
                    context.incomplete = false;
                    context.completions = completer.getSuggestions(args);
                });
            },
            argCount: "*"
        },
        true); // }}}

})();

// vi: ts=4 sw=4 et foldmethod=marker commentstring=\ //\ %s
