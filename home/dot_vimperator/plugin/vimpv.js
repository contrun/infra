//                                      _
//         ___ _ __   ___ _ __ ___   __| |
//        / __| '_ \ / __| '_ ` _ \ / _` |
//        \__ | |_) | (__| | | | | | (_| |
//        |___| .__/ \___|_| |_| |_|\__,_|
//             |_|
//
//                    Vimpv
//               Created by: spcmd
//           http://spcmd.github.io
//           https://github.com/spcmd
//           https://gist.github.com/spcmd
//
// Vimpv is a javascript plugin for Vimperator
// which allows you to follow/open video urls with mpv.
// Tested with Youtube and Vimeo videos.
//
// Usage: the default key map is ;m
// You can map the default key to something else,
// for example, if you don't use the 'mark' command
// you can map it to 'm' in your .vimperatorrc:
// nmap m ;m
//
// For embedded and iframe videos the default keymap
// is ;e

hints.addMode ("m", "Vimpv > Play video URL: ",

     function(elem) {
         liberator.echomsg("Vimpv Playing: "+elem.title),
         //liberator.execute("silent !mpv '"+ elem.href+"'&")
         liberator.execute("silent !urxvtc -e mpv '"+ elem.href+"'&")
     },
     function () "//a" //<a> html tags for video URLs
);

hints.addMode ("e", "Vimpv > Play embedded video: ",

     function(elem) {
         liberator.echomsg("Vimpv Playing: "+elem.src)
         //liberator.execute("silent !mpv '"+ elem.src+"'&")
         liberator.execute("silent !urxvtc -e mpv '"+ elem.src+"'&")
     },
     function () "//embed | //iframe" //<embed> and <iframe> html tags for embedded videos
);
