"""
extract/lambda_function.py

AWS Lambda handler that extracts all tracks from a Spotify playlist
and writes the raw JSON response to S3.

Auth: Spotify OAuth 2.0 Authorization Code Flow with a pre-generated
refresh token (see docs/setup.md for the one-time local authorization
step). Client Credentials flow is not used here, since recent Spotify
API changes require user-authorized access to read playlist items.

Note: this bypasses spotipy's built-in playlist_tracks()/playlist_items()
methods, which still route to a deprecated /tracks endpoint that returns
403 Forbidden. Instead, this calls the current /playlists/{id}/items
endpoint directly via `requests`, using the access token spotipy provides.

Environment variables required:
    CLIENT_ID               Spotify app Client ID
    CLIENT_SECRET            Spotify app Client Secret
    SPOTIFY_REFRESH_TOKEN     Refresh token from the one-time local auth flow
    PLAYLIST_LINK             Default playlist URL (used if event has none)
    RAW_BUCKET_NAME           S3 bucket to write raw JSON into

IAM: execution role needs s3:PutObject on RAW_BUCKET_NAME.
"""

import json
import os
import boto3
import requests
from datetime import datetime, timezone
from spotipy.oauth2 import SpotifyOAuth
from spotipy.cache_handler import MemoryCacheHandler

s3 = boto3.client('s3')


def lambda_handler(event, context):

    client_id = os.environ.get('CLIENT_ID')
    client_secret = os.environ.get('CLIENT_SECRET')
    refresh_token = os.environ.get('SPOTIFY_REFRESH_TOKEN')
    bucket_name = os.environ.get('RAW_BUCKET_NAME')

    if not bucket_name:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': "Missing RAW_BUCKET_NAME environment variable"})
        }

    # MemoryCacheHandler avoids spotipy trying to write a token cache file
    # to Lambda's read-only filesystem.
    auth_manager = SpotifyOAuth(
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri="http://127.0.0.1:8888/callback",
        scope="playlist-read-private playlist-read-collaborative",
        cache_handler=MemoryCacheHandler()
    )

    # Silent, server-to-server token refresh -- no login/browser step,
    # which is required since Lambda has no way to run an interactive
    # OAuth flow.
    token_info = auth_manager.refresh_access_token(refresh_token)
    access_token = token_info['access_token']

    # event can override the default playlist for manual/test invocations;
    # otherwise falls back to the PLAYLIST_LINK environment variable, which
    # is what the scheduled daily trigger relies on.
    playlist_link = event.get('playlist_link') or os.environ.get('PLAYLIST_LINK')

    if not playlist_link:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': "No playlist_link provided in event or PLAYLIST_LINK env var"})
        }

    playlist_uri = playlist_link.split("/")[-1].split("?")[0]

    # Fetch all playlist items, following pagination via the 'next' field
    # Spotify returns until it's null.
    all_items = []
    url = f"https://api.spotify.com/v1/playlists/{playlist_uri}/items"
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {"limit": 50, "offset": 0}

    while url:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        all_items.extend(data.get("items", []))
        url = data.get("next")
        params = {}  # subsequent pages' params are already in the 'next' URL

    # Write raw JSON to S3 under raw_data/to_processed/, timestamped so
    # each run's file is kept separately rather than overwritten.
    now = datetime.now(timezone.utc)
    filename = f"spotify_raw_{now.strftime('%Y-%m-%d_%H-%M-%S')}.json"
    s3_key = f"raw_data/to_processed/{filename}"

    s3.put_object(
        Bucket=bucket_name,
        Key=s3_key,
        Body=json.dumps(all_items),
        ContentType='application/json'
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Successfully wrote playlist data to S3',
            'bucket': bucket_name,
            'key': s3_key,
            'track_count': len(all_items)
        })
    }
