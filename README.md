# Audio Lifter

A simple macOS GUI for downloading YouTube audio as 192 kbps MP3 files, with optional drum transcription to MIDI via omnizart.

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

---

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

---

## Drum transcription to MIDI (optional)

Enabling the **"Transcribe drum part to MIDI"** checkbox in the app will pipe the downloaded audio through [omnizart](https://github.com/Music-and-Culture-Technology-Lab/omnizart) to extract the drum part as a MIDI file, then open it automatically in MuseScore.

omnizart requires **Python 3.8** and cannot be installed into the main project environment. Set it up in its own isolated environment as follows.

### 1. Install Python 3.8 via pyenv

```bash
brew install pyenv
pyenv install 3.8.18
```

### 2. Create a dedicated omnizart environment

```bash
~/.pyenv/versions/3.8.18/bin/python -m venv ~/.omnizart-env
source ~/.omnizart-env/bin/activate
pip install omnizart
```

### 3. Download the model checkpoints

This is a one-time download (roughly 1–2 GB):

```bash
omnizart download-checkpoints
deactivate
```

### 4. Add omnizart to your PATH

Add the following line to your `~/.zshrc` (or `~/.bash_profile`):

```bash
export PATH="$HOME/.omnizart-env/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zshrc
```

The app also checks `~/.omnizart-env/bin/omnizart` directly as a fallback, so this step is only strictly required when running from the Desktop icon.

### 5. Install MuseScore

Download and install [MuseScore](https://musescore.org/en/download) (version 3 or 4). After transcription completes the MIDI file will open in MuseScore automatically.

### Usage

Check **"Transcribe drum part to MIDI"** before clicking Download. After the audio is saved, omnizart will run (expect a few minutes of processing time), and the resulting `.mid` file will open in MuseScore alongside the `.mp3` in Finder.

---

## How it works

1. Paste a YouTube URL into the text box and press **Download** (or hit Return).
2. yt-dlp fetches the best available audio stream and ffmpeg converts it to 192 kbps MP3.
3. On completion, a Finder window opens to the `saved_audio/` folder.
4. If drum transcription is enabled, omnizart analyses the audio and writes a `.mid` file to the same folder, which then opens in MuseScore.
