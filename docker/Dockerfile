# Builds on the same TF version omnizart requires, but uses the CPU-only
# image so no GPU driver is needed on the host.
# Target platform is linux/amd64 — this image is intended to run via
# Docker's emulation layer on Apple Silicon Macs.
FROM --platform=linux/amd64 tensorflow/tensorflow:2.5.0

# System dependencies (mirrors the official omnizart Dockerfile)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    libgl1-mesa-glx \
    ffmpeg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Pre-install build-time requirements before omnizart pulls them in.
# - cython<3      : madmom is incompatible with Cython 3
# - numpy<1.24    : TF 2.5.0 is incompatible with numpy 1.24+ API changes
# - pyfluidsynth==1.3.0 : versions >1.3.0 use the walrus operator (:=)
#                   which requires Python 3.8+; this image runs Python 3.6
RUN pip install --upgrade pip && \
    pip install "cython<3" "numpy<1.24" "pyfluidsynth==1.3.0"

# Install omnizart. pyfluidsynth is pinned above so pip will not upgrade it.
RUN pip install omnizart "pyfluidsynth==1.3.0"

# Download only the drum transcription model checkpoint rather than the
# full suite (~2 GB). The script uses omnizart's own download utility so
# the file lands in exactly the path omnizart expects at runtime.
COPY download_drum_checkpoint.py /tmp/download_drum_checkpoint.py
RUN python /tmp/download_drum_checkpoint.py && rm /tmp/download_drum_checkpoint.py

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
