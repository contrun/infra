// http://marlonyao.iteye.com/blog/776775
// only set string value  
function setPreferenceValue(branch, name, value) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch(branch);
    var str = Components.classes["@mozilla.org/supports-string;1"].createInstance(Components.interfaces.nsISupportsString);
    str.data = value;
    prefs.setComplexValue(name, Components.interfaces.nsISupportsString, str);
}
function getPreferenceValue(branch, name) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch(branch);
    //if (prefs.prefHasUserValue(name)) {
    return prefs.getComplexValue(name, Components.interfaces.nsISupportsString).data;
    //} else {
    //  return null;
    //}  
}

function setIntPreferenceValue(branch, name, value) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch(branch);
    prefs.setIntPref(name, value);
}
function getIntPreferenceValue(branch, name) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch(branch);
    return prefs.getIntPref(name);
}

function refresh() {
	tabs.reload(config.browser.mCurrentTab);
}


commands.addUserCommand(["autoproxy", "ap"], "Change autoproxy status",
    function (args) {
        if (args.length == 0) { // print current autoproxy status
            var mode = getPreferenceValue("extensions.autoproxy.", "proxyMode");
            //if (mode == null)
            //{
            //	mode = 'auto';f
            //}
            liberator.echomsg("proxyMode is " + mode);
        } else {
            var arg = args[0].toLowerCase();
            var mode;
            if (arg.indexOf('d') == 0) {
                mode = 'disabled';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", mode);
                liberator.echomsg("set proxyMode to " + mode);
            } else if (arg.indexOf('a') == 0) {
                mode = 'auto';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", mode);
                liberator.echomsg("set proxyMode to " + mode);
            } else if (arg.indexOf('g') == 0) {
                mode = 'global';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", mode);
                liberator.echomsg("set proxyMode to " + mode);
            } else {
                liberator.echoerr("mode should be one of 'disabled', 'auto' or 'global'");
            }
        }
    }, {
        argCount: "?",
    }
);

commands.addUserCommand(["switchproxy", "sp"], "Switch autoproxy status",
    function (args) {
        if (args.length == 0) {
            var mode = getPreferenceValue("extensions.autoproxy.", "proxyMode");
            //if (mode == null)
            if (mode == 'auto') {
                //mode = 'auto';
                newmode = 'global';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", newmode);
                liberator.echomsg("proxyMode is " + mode + ", switch proxyMode to " + newmode);
            }
            else if (mode == 'global') {
                newmode = 'auto';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", newmode);
                liberator.echomsg("proxyMode is " + mode + ", switch proxyMode to " + newmode);
            }
            else {
                liberator.echoerr("proxyMode is not 'auto' or 'global'");
            }
        }
        else {
            liberator.echoerr("We dont need args...");
        }
    }, {
        argCount: "?",
    }
);

commands.addUserCommand(["switchdefaultproxy", "sdp"], "Switch autoproxy default proxy",
    function (args) {
        if (args.length == 0) {
            var default_proxy = getIntPreferenceValue("extensions.autoproxy.", "default_proxy");
            liberator.echomsg("default proxy is " + default_proxy);
        } else {
            if (isNaN(args)) {
                liberator.echoerr("default proxy should be number");
            }
            else {
                setIntPreferenceValue("extensions.autoproxy.", "default_proxy", args);
                liberator.echomsg("switch autoproxy default proxy to " + args);
            }
        }
    }, {
        argCount: "?",
    }
);

commands.addUserCommand(["switchproxyrefresh", "spr"], "Switch autoproxy status and refresh",
    function (args) {
        if (args.length == 0) {
            var mode = getPreferenceValue("extensions.autoproxy.", "proxyMode");
            //if (mode == null)
            if (mode == 'auto') {
                //mode = 'auto';
                newmode = 'global';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", newmode);
                liberator.echomsg("proxyMode is " + mode + ", switch proxyMode to " + newmode);
                refresh();
            }
            else if (mode == 'global') {
                newmode = 'auto';
                setPreferenceValue("extensions.autoproxy.", "proxyMode", newmode);
                liberator.echomsg("proxyMode is " + mode + ", switch proxyMode to " + newmode);
                refresh();
            }
            else {
                liberator.echoerr("proxyMode is not 'auto' or 'global'");
            }
        }
        else {
            liberator.echoerr("We dont need args...");
        }
    }, {
        argCount: "?",
    }
);

//foxyproxy.xml下的<proxy name
var EurekaVPT = "2024895854";
var ShadowSocks = "3449804312";
var GoAgent = "2566479489";
var Default = "3213569921";
var Patterns = "patterns";
var Disabled = "disabled";

var ShadowSocks_Name = "ShadowSocks";
var GoAgent_Name = "GoAgent";
var Default_Name = "Default";
var EurekaVPT_Name = "EurekaVPT";
var Patterns_Name = "Patterns";
var Disabled_Name = "Disabled";

commands.addUserCommand(["foxyproxy","fp"],"set FoxyProxy Mode",
	function (args) {
	if (args.length == 0){
		var proxyMode;
		switch (foxyproxy.fp.mode){
		case ShadowSocks:
			proxyMode = ShadowSocks_Name;
			break;
		case GoAgent:
			proxyMode = GoAgent_Name;
			break;
		case Default:
			proxyMode = Default_Name;
			break;
		case Patterns:
			proxyMode = Patterns_Name;
			break;
		case Disabled:
			proxyMode = Disabled_Name;
			break; 
        case EurekaVPT:
            proxyMode = EurekaVPT_Name;
            break;
		default:
			proxyMode = foxyproxy.fp.mode;
		}
		liberator.echomsg(proxyMode);
	}
	else if (args == ShadowSocks_Name || args == "ss" || args == "s"){
	foxyproxy.fp.setMode(ShadowSocks, true);
	liberator.echomsg(ShadowSocks_Name);
}
 else if (args == GoAgent_Name || args == "ga" || args == "g"){
	foxyproxy.fp.setMode(GoAgent,true);
	liberator.echomsg(GoAgent_Name);
} else if (args == Default_Name || args == "df"){
	foxyproxy.fp.setMode(Default,true);
	liberator.echomsg(Default_Name);
} else if (args == Patterns_Name || args == "pt" || args == "p"){
	foxyproxy.fp.setMode(Patterns,true);
	liberator.echomsg(Patterns_Name);
}else if (args == Disabled_Name || args == "da"){
	foxyproxy.fp.setMode(Disabled,true);
	liberator.echomsg(Disabled_Name);
}else if (args == EurekaVPT_Name || args =="erk" || args == "e"){
    foxyproxy.fp.setMode(EurekaVPT,true);
    liberator.echomsg(EurekaVPT_Name)
}
}
);

commands.addUserCommand(["foxyproxyrefresh","fpr"],"set FoxyProxy Mode and refresh",
	function (args) {
	if (args.length == 0){
		var proxyMode;
		switch (foxyproxy.fp.mode){
		case ShadowSocks:
			proxyMode = ShadowSocks_Name;
			break;
		case GoAgent:
			proxyMode = GoAgent_Name;
			break;
		case Default:
			proxyMode = Default_Name;
			break;
		case Patterns:
			proxyMode = Patterns_Name;
			break;
		case Disabled:
			proxyMode = Disabled_Name;
			break; 
        case EurekaVPT:
            proxyMode = EurekaVPT_Name;
            break;
		default:
			proxyMode = foxyproxy.fp.mode;
		}
		liberator.echomsg(proxyMode);
	}
	else if (args == ShadowSocks_Name || args == "ss" || args == "s"){
	foxyproxy.fp.setMode(ShadowSocks, true);
	liberator.echomsg(ShadowSocks_Name);
	refresh();
}
 else if (args == GoAgent_Name || args == "ga" || args == "g"){
	foxyproxy.fp.setMode(GoAgent,true);
	liberator.echomsg(GoAgent_Name);
	refresh();
} else if (args == Default_Name || args == "df"){
	foxyproxy.fp.setMode(Default,true);
	liberator.echomsg(Default_Name);
	refresh();
} else if (args == Patterns_Name || args == "pt" || args == "p"){
	foxyproxy.fp.setMode(Patterns,true);
	liberator.echomsg(Patterns_Name);
	refresh();
}else if (args == Disabled_Name || args == "da"){
	foxyproxy.fp.setMode(Disabled,true);
	liberator.echomsg(Disabled_Name);
	refresh();
}else if (args == EurekaVPT_Name || args =="erk" || args == "e"){
    foxyproxy.fp.setMode(EurekaVPT,true);
    liberator.echomsg(EurekaVPT_Name)
    refresh();
}
}
);