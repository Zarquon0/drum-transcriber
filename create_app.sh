#!/bin/bash
set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
UV="$(command -v uv 2>/dev/null || echo "$HOME/.local/bin/uv")"
APPPATH="$HOME/Desktop/Audio Lifter.app"

ASCRIPT="do shell script \"'$UV' run --directory '$PROJ_DIR' python main.py >> /tmp/audio-lifter.log 2>&1 &\""

echo "$ASCRIPT" | osacompile -o "$APPPATH"

# Set a nicer icon using the built-in iTunes/Music note icon as a stand-in
ICON_SOURCE="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericURLIcon.icns"
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$APPPATH/Contents/Resources/droplet.icns"
fi

echo "Created: $APPPATH"
echo "Double-click 'Audio Lifter' on your Desktop to launch."
