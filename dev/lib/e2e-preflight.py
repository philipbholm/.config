"""Check the selected local API and available frontend ports before Playwright starts."""

import json
import os
import socket
import sys
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def main():
    api_url = os.environ["E2E_API_URL"]
    request = Request(
        api_url,
        data=json.dumps({"query": "{ __typename }"}).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=10) as response:
            result = json.load(response)
        if (not isinstance(result, dict) or result.get("errors")
                or not isinstance(result.get("data"), dict)
                or result["data"].get("__typename") != "Query"):
            raise ValueError("GraphQL readiness query did not succeed")
    except (URLError, ValueError, TimeoutError) as error:
        sys.exit(f"Error: E2E API is not ready at {api_url}: {error}")

    # The standalone Playwright config reuses existing servers. Refuse occupied
    # preview ports so a previous run cannot supply a frontend with another API.
    for url in sorted({os.environ["FRONTEND_BASE_URL"], os.environ["REGISTRIES_BASE_URL"]}):
        port = urlparse(url).port
        for family, kind, protocol, _, address in socket.getaddrinfo("localhost", port, type=socket.SOCK_STREAM):
            try:
                with socket.socket(family, kind, protocol) as listener:
                    listener.bind(address)
            except OSError:
                sys.exit(f"Error: E2E frontend port {port} is occupied. Stop its server and rerun.")


if __name__ == "__main__":
    main()
