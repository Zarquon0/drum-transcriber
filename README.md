# Audio Lifter

A simple macOS GUI for downloading YouTube audio as 192 kbps MP3 files.

## Dependencies

Install the following before setting up the project.

### Homebrew

If you don't have Homebrew installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### uv (Python package manager)

```bash
brew install uv
```

### Python 3.12 with Tkinter support

```bash
brew install python-tk@3.12
```

### ffmpeg (required for MP3 conversion)

```bash
brew install ffmpeg
```

## Setup after git clone

```bash
git clone <repo-url>
cd audio-lifter

# Create the virtual environment using Homebrew's Python (which has Tkinter)
uv venv --python "$(brew --prefix)/bin/python3.12"

# Install Python dependencies
uv sync
```

## Running the app

```bash
uv run python main.py
```

## Creating a clickable Desktop icon

Run this once after setup to place an **Audio Lifter** app on your Desktop:

```bash
bash create_app.sh
```

Double-click **Audio Lifter** on your Desktop to launch the app at any time. If you ever move the project folder, re-run `create_app.sh` to regenerate the icon with the updated path.

## Usage

1. Paste a YouTube URL into the text box and press **Download** (or hit Return).
2. Progress is shown in the status bar and log area.
3. When the download finishes, a Finder window opens automatically to the `saved_audio/` folder where your MP3 is waiting.
