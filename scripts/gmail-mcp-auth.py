#!/usr/bin/env python3
"""
Headless OAuth2 helper for Gmail MCP.
Usage:
  1. Generate auth URL:
       uv run gmail-mcp-auth.py
  2. Open URL in browser, authorize, copy the redirect URL's ?code=... parameter
  3. Exchange code for token:
       uv run gmail-mcp-auth.py '4/0A...'
"""

import json, os, sys
from urllib.parse import urlparse, parse_qs
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]
CREDS = os.path.expanduser("~/.config/gmail-mcp/credentials.json")
TOKEN = os.path.expanduser("~/.config/gmail-mcp/token.json")
VERIFIER = os.path.expanduser("~/.config/gmail-mcp/code_verifier.txt")


def step1_generate_url():
    flow = InstalledAppFlow.from_client_secrets_file(CREDS, SCOPES)
    flow.redirect_uri = "http://localhost"
    auth_url, _ = flow.authorization_url(prompt="consent", access_type="offline")
    with open(VERIFIER, "w") as f:
        f.write(flow.code_verifier)
    print("\nOpen this URL in your browser:\n")
    print(auth_url)
    print("\nAfter authorizing, the browser will redirect to a broken localhost page.")
    print("Copy the FULL redirect URL from the address bar, then run:")
    print(f"  uv run {sys.argv[0]} 'THE_CODE_FROM_THE_URL'")
    print()


def step2_exchange_code(code):
    if not os.path.exists(VERIFIER):
        print("No code_verifier found. Run without arguments first to generate the auth URL.")
        sys.exit(1)
    with open(VERIFIER) as f:
        code_verifier = f.read()
    flow = InstalledAppFlow.from_client_secrets_file(CREDS, SCOPES)
    flow.redirect_uri = "http://localhost"
    flow.fetch_token(code=code, code_verifier=code_verifier)
    creds = flow.credentials
    with open(TOKEN, "w") as f:
        f.write(creds.to_json())
    os.remove(VERIFIER)
    print(f"Token saved to {TOKEN}")


if __name__ == "__main__":
    if not os.path.exists(CREDS):
        print(f"Error: {CREDS} not found.")
        print("Download your OAuth credentials from Google Cloud Console and save them there.")
        sys.exit(1)

    if len(sys.argv) > 1:
        code = sys.argv[1]
        if code.startswith("http"):
            parsed = urlparse(code)
            code = parse_qs(parsed.query).get("code", [None])[0]
        if not code:
            print("Could not extract code from argument. Paste the full redirect URL or just the ?code= parameter.")
            sys.exit(1)
        step2_exchange_code(code)
    else:
        step1_generate_url()
