# Spotify → AWS ETL Pipeline

An end-to-end, serverless data pipeline that extracts playlist data from the Spotify Web API, stores it in Amazon S3, and (in progress) transforms it into clean, queryable tables using AWS Glue and Athena.

Built as a hands-on data engineering project to practice API integration, serverless compute, cloud storage, and working around real-world API changes and deprecations.

## Architecture

```
Spotify API
    ↓
Amazon CloudWatch / EventBridge (daily trigger)
    ↓
AWS Lambda (extract)
    ↓
Amazon S3 (raw JSON)
    ↓  [in progress]
AWS Lambda (transform)
    ↓
Amazon S3 (clean CSV/Parquet — artist, album, track tables)
    ↓
AWS Glue Crawler (schema inference)
    ↓
AWS Glue Data Catalog
    ↓
Amazon Athena (SQL analytics)
```

**Status:** Extraction stage complete and deployed. Transform, Glue, and Athena stages are next.

## What it does

1. Authenticates with the Spotify Web API using OAuth 2.0 Authorization Code Flow (with refresh-token support for unattended, scheduled runs)
2. Pulls all tracks from a target playlist, handling pagination automatically
3. Writes the raw JSON response to an S3 bucket (`raw_data/to_processed/`), timestamped per run
4. Designed to run daily and unattended via a scheduled trigger, with no manual login required after initial setup

## Tech stack

- **Python** (spotipy + `requests`)
- **AWS Lambda** — serverless extraction logic
- **Amazon S3** — raw data storage
- **AWS CloudWatch / EventBridge** — scheduled daily trigger
- **AWS Glue & Athena** *(planned)* — schema cataloging and SQL analytics
- **Spotify Web API** (OAuth 2.0 Authorization Code Flow)

## Key engineering challenges solved

This project ran into several real, current issues with the Spotify Web API that aren't covered in most tutorials — solving them was most of the actual engineering work:

- **API endpoint deprecation:** Spotify's `playlist_tracks()` / `playlist_items()` methods in `spotipy` route to a now-deprecated `/tracks` endpoint that returns `403 Forbidden`. Fixed by calling the current `/playlists/{id}/items` endpoint directly via `requests`, bypassing the outdated library method.
- **Client Credentials flow restrictions:** As of recent Spotify platform changes, reading playlist track data now requires user-authorized access — Client Credentials (app-only) auth is no longer sufficient. Migrated to Authorization Code Flow with refresh tokens.
- **Editorial playlist restrictions:** Spotify-owned/algorithmic playlists (e.g. Discover Weekly, Top 50) are permanently excluded from third-party read access, regardless of auth method — confirmed via live 404 responses. The pipeline is designed around user-created playlists instead.
- **Unattended auth in Lambda:** Interactive login (`input()`, browser redirects) can't run in Lambda. Solved by performing the OAuth handshake once locally to obtain a refresh token, then using `refresh_access_token()` silently on every Lambda invocation.
- **Read-only Lambda filesystem:** `spotipy`'s default file-based token cache fails silently in Lambda. Swapped to `MemoryCacheHandler` to avoid filesystem writes.

## Setup

### 1. Spotify Developer App
- Create an app at the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
- Note your **Client ID** and **Client Secret**
- Add a redirect URI (e.g. `http://127.0.0.1:8888/callback`)

### 2. Generate a refresh token (one-time, local)
Run the OAuth flow locally once to authorize the app and obtain a refresh token:
```python
from spotipy.oauth2 import SpotifyOAuth

auth_manager = SpotifyOAuth(
    client_id="YOUR_CLIENT_ID",
    client_secret="YOUR_CLIENT_SECRET",
    redirect_uri="http://127.0.0.1:8888/callback",
    scope="playlist-read-private playlist-read-collaborative",
    open_browser=False
)
print(auth_manager.get_authorize_url())
# Log in via the printed URL, approve, then paste the redirect URL below
redirect_response = input("Paste the full redirect URL here: ")
code = auth_manager.parse_response_code(redirect_response)
token_info = auth_manager.get_access_token(code, as_dict=True)
print(token_info["refresh_token"])
```

### 3. AWS Lambda configuration
- **Runtime:** Python 3.13
- **Layer:** `spotipy` and its dependencies, packaged as a Lambda Layer
- **Environment variables:**

| Key | Description |
|---|---|
| `CLIENT_ID` | Spotify app Client ID |
| `CLIENT_SECRET` | Spotify app Client Secret |
| `SPOTIFY_REFRESH_TOKEN` | Refresh token from step 2 |
| `PLAYLIST_LINK` | Default playlist URL to extract |
| `RAW_BUCKET_NAME` | S3 bucket for raw data |

- **IAM permissions:** `s3:PutObject` on the target bucket
- **Trigger:** CloudWatch/EventBridge scheduled rule (daily)

## Repository structure

```
.
├── lambda_function.py     # Extraction Lambda handler
├── requirements.txt        # spotipy, requests
└── README.md
```

## Roadmap

- [x] Spotify authentication (Authorization Code Flow + refresh tokens)
- [x] Playlist extraction with pagination
- [x] Raw JSON storage in S3
- [ ] Transform Lambda — flatten nested JSON into artist/album/track tables, drop duplicates, S3 event-triggered
- [ ] AWS Glue Crawler — schema inference and Data Catalog registration
- [ ] Amazon Athena — SQL analytics on the cataloged data
- [ ] CloudWatch/EventBridge daily schedule wired end-to-end

## What this project demonstrates

- Working with a real, evolving third-party API (including handling breaking changes as they happened)
- OAuth 2.0 authentication flows and secure credential handling in a serverless environment
- Serverless architecture design on AWS (Lambda, S3, IAM)
- Debugging based on live API responses and error traces, rather than assuming documentation is current
