"""
Replace the response body and Location header with the new URL.
This script is useful when we are using mitmproxy as a reverse proxy and
want to replace the old URL with the new URL in the response body and Location header.

You can use this script with the following command:
    $ export OLD_URL="http://old-url.com"
    $ listening_port=8080
    $ export NEW_URL="http://127.0.0.1:$listening_port"
    $ mitmproxy -s replace_response_body.py --mode reverse:$OLD_URL@$listening_port
"""

import os
from mitmproxy import http


def response(flow: http.HTTPFlow) -> None:
    # Get urls from the environment variables
    old_url = os.getenv("OLD_URL")
    new_url = os.getenv("NEW_URL")
    if old_url is None or new_url is None:
        return
    if flow.response:
        if flow.response.content:
            flow.response.content = flow.response.content.replace(
                    old_url.encode(encoding="utf-8"), new_url.encode(encoding="utf-8")
            )
        if "Location" in flow.response.headers:
            flow.response.headers["Location"] = flow.response.headers["Location"].replace(old_url, new_url)
