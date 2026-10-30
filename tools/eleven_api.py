"""ElevenLabs API access for the asset tools.

The key is read from the ELEVENLABS_API_KEY environment variable, or from the
gitignored .env file at the repo root (ELEVENLABS_API_KEY=...). Never commit it.

Usage: python eleven_api.py   (checks that the key works and prints the account's credit usage)
In other tools: from eleven_api import session; s = session(); s.post(API + "/v1/text-to-speech/...")
"""
import os
import sys

import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.elevenlabs.io"


def load_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for raw in f:
                name, _, value = raw.strip().partition("=")
                if name.strip() == "ELEVENLABS_API_KEY":
                    return value.strip().strip("\"'")
    sys.exit("ELEVENLABS_API_KEY not set. Add it to .env at the repo root (see .env.example).")


def session():
    s = requests.Session()
    s.headers["xi-api-key"] = load_key()
    return s


def main():
    r = session().get(API + "/v1/user/subscription", timeout=20)
    if r.status_code == 401:
        sys.exit("ElevenLabs rejected the key (401). Check the value in .env.")
    if r.status_code == 403:
        print("Key accepted, but it is scoped without 'User: read', so credit usage can't be shown.")
        return
    r.raise_for_status()
    sub = r.json()
    print(f"ElevenLabs key OK. Tier: {sub.get('tier')}, "
          f"credits used: {sub.get('character_count')} / {sub.get('character_limit')}")


if __name__ == "__main__":
    main()
