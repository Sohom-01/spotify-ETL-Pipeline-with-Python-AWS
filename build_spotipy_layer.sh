#!/bin/bash
#
# build_spotipy_layer.sh
#
# Builds a Lambda Layer zip containing spotipy and its dependencies,
# packaged in the folder structure AWS Lambda expects for layers.
#
# Run this in AWS CloudShell (recommended) or a Linux environment to
# avoid Windows/Linux binary mismatches with Lambda's runtime.
#
# Usage:
#   chmod +x build_spotipy_layer.sh
#   ./build_spotipy_layer.sh
#
# Output:
#   spotipy-layer.zip — upload this directly in the Lambda console
#   under Layers -> Create layer -> Upload a .zip file.
#   If the file exceeds 10 MB, upload it to S3 first and use the
#   "Amazon S3 link" option instead.

set -e  # exit immediately if any command fails

PYTHON_VERSION="3.13"
BUILD_DIR="python"
ZIP_NAME="spotipy-layer.zip"

echo "Cleaning up any previous build..."
rm -rf "$BUILD_DIR" "$ZIP_NAME"

echo "Creating layer folder structure..."
mkdir -p "$BUILD_DIR"

echo "Installing spotipy and dependencies into $BUILD_DIR/ ..."
pip install spotipy==2.26.0 -t "$BUILD_DIR" \
    --platform manylinux2014_x86_64 \
    --python-version "$PYTHON_VERSION" \
    --only-binary=:all:

echo "Zipping layer..."
zip -r "$ZIP_NAME" "$BUILD_DIR" > /dev/null

echo "Done."
echo "Created: $ZIP_NAME"
echo "Upload this file in the Lambda console under Layers -> Create layer."
echo "Set 'Compatible runtimes' to Python $PYTHON_VERSION."
