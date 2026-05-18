#!/usr/bin/env zsh
# Sets up the omnizart drum-transcription environment at ~/.omnizart-env.
# Safe to re-run: each step checks whether it has already been done.
# Tested on Apple Silicon macOS with Anaconda. Requires conda to be installed.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ENV_PATH="$HOME/.omnizart-env"

# ── 1. Locate conda ─────────────────────────────────────────────────────────

typeset -a CONDA_CANDIDATES
CONDA_CANDIDATES=(
    "$HOME/opt/anaconda3"
    "$HOME/anaconda3"
    "$HOME/miniconda3"
    "$HOME/miniforge3"
    "/opt/homebrew/anaconda3"
    "/opt/homebrew/miniforge3"
    "/usr/local/anaconda3"
    "/usr/local/miniconda3"
)

CONDA_BASE=""
for candidate in "${CONDA_CANDIDATES[@]}"; do
    if [[ -f "$candidate/bin/conda" ]]; then
        CONDA_BASE="$candidate"
        break
    fi
done

if [[ -z "$CONDA_BASE" ]]; then
    echo "Error: conda not found in common locations. Install Anaconda or Miniconda first." >&2
    exit 1
fi

source "$CONDA_BASE/etc/profile.d/conda.sh"
CONDA="$CONDA_BASE/bin/conda"
PIP="$ENV_PATH/bin/pip"
PYTHON="$ENV_PATH/bin/python"

echo "Using conda at: $CONDA_BASE"

# ── 2. Create conda environment ──────────────────────────────────────────────

if [[ -d "$ENV_PATH" ]]; then
    echo "Environment already exists at $ENV_PATH — skipping creation."
else
    echo "Creating Python 3.9 environment at $ENV_PATH ..."
    "$CONDA" create -p "$ENV_PATH" python=3.9 -y
fi

# ── 3. Install Apple ARM-native TensorFlow ───────────────────────────────────

if "$PYTHON" -c "import tensorflow" &>/dev/null 2>&1; then
    echo "TensorFlow already installed — skipping."
else
    echo "Installing Apple tensorflow-deps 2.9.0 ..."
    "$CONDA" install -c apple tensorflow-deps=2.9.0 -p "$ENV_PATH" -y

    echo "Installing tensorflow-macos 2.9.0 + tensorflow-metal 0.5.0 ..."
    "$PIP" install tensorflow-macos==2.9.0 tensorflow-metal==0.5.0
fi

# ── 4. Build prerequisites for madmom ────────────────────────────────────────
# madmom requires Cython <3 and setuptools <60 to compile on macOS.

echo "Installing madmom build prerequisites ..."
"$PIP" install "setuptools<60" "cython<3" --quiet

echo "Installing madmom ..."
"$PIP" install madmom --no-build-isolation --quiet

# ── 5. Install omnizart (without its dependency resolver) ────────────────────
# We skip --deps because omnizart pins vamp, which doesn't build on ARM.

if "$PYTHON" -c "import omnizart" &>/dev/null 2>&1; then
    echo "omnizart already installed — skipping."
else
    echo "Installing omnizart --no-deps ..."
    "$PIP" install omnizart --no-deps --quiet
fi

# ── 6. Install remaining runtime dependencies (excluding vamp) ───────────────
# Version pins chosen to satisfy the full dependency graph:
#   numpy 1.23.x  – last series with np.float (removed in 1.24); madmom needs it
#   opencv 4.8.x  – last series with numpy <2 wheels
#   h5py <3.11    – last series that doesn't require numpy >=2
# onnxruntime is used as a fallback model loader when weights.h5 is unavailable.

echo "Installing omnizart runtime dependencies ..."
"$PIP" install \
    "numpy==1.23.5" \
    "opencv-python-headless==4.8.1.78" \
    "h5py<3.11" \
    "protobuf<3.20" \
    onnxruntime \
    librosa \
    pretty_midi \
    pyFluidSynth \
    soundfile \
    mir_eval \
    pyyaml \
    click \
    colorama \
    Pillow \
    tqdm \
    jsonschema \
    --quiet

# ── 7. Install vamp stub ─────────────────────────────────────────────────────
# omnizart imports the vamp module at the top of its chroma feature file.
# Drum transcription never calls vamp.collect(), but the import still runs.
# We provide a lightweight stub so the import succeeds on ARM where the real
# Vamp plugin SDK won't compile.

VAMP_STUB="$ENV_PATH/lib/python3.9/site-packages/vamp.py"
if [[ -f "$VAMP_STUB" ]]; then
    echo "vamp stub already present — skipping."
else
    echo "Installing vamp stub ..."
    cat > "$VAMP_STUB" <<'VAMP'
# Stub for the vamp Python package.
# The real package requires the Vamp plugin SDK which does not build on
# Apple Silicon. Only chord transcription calls vamp.collect(); drum
# transcription imports this module but never invokes it at runtime.

def collect(*args, **kwargs):
    raise RuntimeError(
        "vamp is not available on Apple Silicon — "
        "chord transcription is not supported in this installation."
    )
VAMP
fi

# ── 8. Patch omnizart/base.py ─────────────────────────────────────────────────
# Three patches applied here:
#   A) Replace model_from_yaml (removed in keras 2.6, CVE-2021-26911) with
#      yaml.full_load + model_from_json.
#   B) Insert _OnnxModelWrapper class so the drum model can be loaded via
#      onnxruntime when weights.h5 is unavailable (Google Drive link is stale).
#   C) Update _load_model to try weights.h5 first, fall back to model.onnx.

echo "Applying omnizart/base.py patches ..."
"$PYTHON" - <<'PYEOF'
import sys, pathlib, re

base_path = pathlib.Path(sys.prefix) / "lib/python3.9/site-packages/omnizart/base.py"
src = base_path.read_text()

# Already fully patched?
if "_OnnxModelWrapper" in src:
    print("  base.py already fully patched — skipping.")
    sys.exit(0)

# ── Patch A: model_from_yaml → model_from_json ──────────────────────────────
if "yaml.full_load" not in src:
    src = src.replace(
        "from tensorflow.keras.models import model_from_yaml",
        "import json\nimport yaml\nfrom tensorflow.keras.models import model_from_json",
    )
    src = src.replace(
        'return model_from_yaml(open(arch_path, "r").read(), custom_objects=custom_objects)',
        'with open(arch_path, "r") as f:\n            arch_dict = yaml.full_load(f)\n        return model_from_json(json.dumps(arch_dict), custom_objects=custom_objects)',
    )
    if "model_from_json" not in src:
        print("  ERROR: patch A target not found in base.py")
        sys.exit(1)
    print("  Applied patch A: model_from_yaml → model_from_json")

# ── Patch B: insert _OnnxModelWrapper before class BaseTranscription ─────────
wrapper = (
    "\nclass _OnnxModelWrapper:\n"
    '    """Wraps onnxruntime InferenceSession to satisfy model.predict()."""\n'
    "    def __init__(self, session):\n"
    "        self._session = session\n"
    "        self._input_name = session.get_inputs()[0].name\n"
    "        self._output_name = session.get_outputs()[0].name\n"
    "\n"
    "    def predict(self, x):\n"
    "        import numpy as np\n"
    "        return self._session.run(\n"
    "            [self._output_name],\n"
    "            {self._input_name: np.array(x, dtype=np.float32)},\n"
    "        )[0]\n"
    "\n"
)
if "class BaseTranscription(" not in src:
    print("  ERROR: BaseTranscription class not found in base.py")
    sys.exit(1)
src = src.replace("class BaseTranscription(", wrapper + "class BaseTranscription(", 1)

# ── Patch C: ONNX fallback in _load_model ────────────────────────────────────
# Match from 'model = self._get_model_from_yaml(...)' through 'return model, settings'
# using DOTALL so we don't need to worry about exact newline placement.
old_body = re.search(
    r"model = self\._get_model_from_yaml\(arch_path, custom_objects=custom_objects\)"
    r".*?return model, settings",
    src,
    re.DOTALL,
)
if old_body is None:
    print("  ERROR: _load_model body not found in base.py")
    sys.exit(1)

new_body = (
    'onnx_path = os.path.join(os.path.dirname(weight_path), "model.onnx")\n'
    "        if os.path.exists(weight_path):\n"
    "            model = self._get_model_from_yaml(arch_path, custom_objects=custom_objects)\n"
    "            try:\n"
    "                model.load_weights(weight_path)\n"
    "            except OSError:\n"
    "                raise FileNotFoundError(\n"
    '                    f"Weight file not found: {weight_path}. Perhaps not yet downloaded?\\n"\n'
    "                    \"Try execute 'omnizart download-checkpoints'\"\n"
    "                )\n"
    "        elif os.path.exists(onnx_path):\n"
    "            import onnxruntime as ort\n"
    '            logger.info("weights.h5 not found; loading ONNX model from %s", onnx_path)\n'
    "            model = _OnnxModelWrapper(ort.InferenceSession(onnx_path))\n"
    "        else:\n"
    "            raise FileNotFoundError(\n"
    '                f"Weight file not found: {weight_path}. Perhaps not yet downloaded?\\n"\n'
    "                \"Try execute 'omnizart download-checkpoints'\"\n"
    "            )\n"
    "\n"
    "        settings = self.setting_class(conf_path=conf_path)\n"
    "        return model, settings"
)
src = src[:old_body.start()] + new_body + src[old_body.end():]

if "_OnnxModelWrapper" not in src:
    print("  ERROR: patches not applied correctly")
    sys.exit(1)

base_path.write_text(src)
print("  base.py patched successfully (all patches applied).")
PYEOF

# ── 9. Download drum model checkpoint ────────────────────────────────────────
# The Google Drive weights.h5 link is no longer publicly accessible.  We
# download the ONNX export from the GitHub release instead; base.py falls back
# to onnxruntime when weights.h5 is absent.  The download script also cleans
# up any stale files left by earlier versions of this script.

CHECKPOINT="$ENV_PATH/lib/python3.9/site-packages/omnizart/checkpoints/drum/drum_keras/model.onnx"
if [[ -f "$CHECKPOINT" ]]; then
    echo "Drum checkpoint already downloaded — skipping."
else
    echo "Downloading drum model checkpoint (~30 MB) ..."
    "$PYTHON" "$SCRIPT_DIR/docker/download_drum_checkpoint.py"
fi

# ── 10. Smoke test ────────────────────────────────────────────────────────────

echo "Running smoke test ..."
"$PYTHON" - <<'PYEOF'
from omnizart.drum import app as drum_app
print("  omnizart drum import OK")
PYEOF

echo ""
echo "omnizart environment ready at $ENV_PATH"
