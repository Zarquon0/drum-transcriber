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

Enabling the **"Transcribe drum part to MIDI"** checkbox runs omnizart locally to extract the drum part as a MIDI file, then opens it automatically in MuseScore.

omnizart requires a patched environment due to Apple Silicon and dependency compatibility issues. The setup script handles everything automatically.

### 1. Run the setup script

From the project root, run once:

```bash
zsh setup_omnizart.sh
```

This will:
- Create a conda environment at `~/.omnizart-env` with Python 3.9
- Install ARM-native TensorFlow 2.9 with Metal GPU acceleration
- Build and install all required dependencies with compatible version pins
- Install a stub for the `vamp` Vamp plugin (ARM-incompatible; not needed for drum transcription)
- Patch omnizart's model loader to use `model_from_json` instead of the removed `model_from_yaml`
- Download the drum model checkpoint (~30 MB)

The script is safe to re-run — each step checks whether it has already completed.

**Prerequisite:** [Anaconda](https://www.anaconda.com/download) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html) must be installed.

### 2. Install MuseScore

Download and install [MuseScore](https://musescore.org/en/download) (version 3 or 4). After transcription completes the MIDI file will open in MuseScore automatically.

### Usage

Check **"Transcribe drum part to MIDI"** before clicking Download. After the audio is saved, omnizart will run (expect a few minutes) and the resulting `.mid` file will open in MuseScore alongside the audio file in Finder. Omnizart's processing stages are logged in real-time in the app's log window.

---

## How it works

1. Paste a YouTube URL into the text box and press **Download** (or hit Return).
2. yt-dlp fetches the best available audio stream and ffmpeg converts it to WAV.
3. On completion, a Finder window opens to the `saved_audio/` folder.
4. If drum transcription is enabled, omnizart analyses the audio using Metal GPU acceleration and writes a `.mid` file to the same folder, which then opens in MuseScore.
