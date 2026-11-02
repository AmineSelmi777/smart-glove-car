from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODEL_PATH = ROOT / "models" / "gesture_rf.joblib"

FS = 50        # Hz
WINDOW = 50    # 1 s
STEP = 10      # pas de 200 ms