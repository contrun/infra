// PLUGIN_INFO {{{
var PLUGIN_INFO = xml`
<VimperatorPlugin>
  <name>qrcode generatero</name>
  <description>Get a qr code for the url/clipboard</description>
  <version>2.1.2</version>
  <author mail="hatespam-nthforloop@yahoo.com">nthforloop</author>
  <license>Check repo htt</license>
  <detail lang='ja'><![CDATA[
    == Commands ==
      :qr
        open url for the generated qr code
  ]]></detail>
</VimperatorPlugin>`;
// }}}


(function () {
  function shorten (url, domain, command) {
    if (!url)
      url = buffer.URL;
      var requestUri = 'https://api.qrserver.com/v1/create-qr-code/?' +
          'size=200x200'+ '&' +
          'data=' + encodeURIComponent(url);
        liberator.open(requestUri, liberator.NEW_TAB );
  }

    commands.addUserCommand(
      ['qr'],
      'Make qrcode',
      function (args) {
        var url = args.literalArg ? util.stringToURLArray(args.literalArg)[0] : buffer.URL;
        shorten(url, '', '');
      }
    );
})();
