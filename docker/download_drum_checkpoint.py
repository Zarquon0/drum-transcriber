"""
Downloads the drum_keras ONNX model checkpoint into the omnizart package
directory. Uses the GitHub release asset (no authentication required).
"""
import os
import shutil
import urllib.request
import omnizart

MODULE_PATH = os.path.dirname(omnizart.__file__)

RELEASE_URL = (
    "https://github.com/Music-and-Culture-Technology-Lab/omnizart"
    "/releases/download/checkpoints-20211001"
)

CHECKPOINT = {
    "url": f"{RELEASE_URL}/drum_keras@model.onnx",
    "save_as": "checkpoints/drum/drum_keras/model.onnx",
}

save_name = os.path.basename(CHECKPOINT["save_as"])
save_dir = os.path.join(MODULE_PATH, os.path.dirname(CHECKPOINT["save_as"]))
os.makedirs(save_dir, exist_ok=True)

# Remove any stale files left by older versions of this script.
stale_h5 = os.path.join(save_dir, "weights.h5")
stale_vars = os.path.join(save_dir, "variables")
if os.path.isfile(stale_h5):
    print(f"Removing stale weights.h5: {stale_h5}")
    os.remove(stale_h5)
if os.path.isdir(stale_vars):
    print(f"Removing stale variables/ directory: {stale_vars}")
    shutil.rmtree(stale_vars)

out_path = os.path.join(save_dir, save_name)
print(f"Downloading drum_keras ONNX model to {out_path} ...")
urllib.request.urlretrieve(CHECKPOINT["url"], out_path)
print("Checkpoint download complete.")
