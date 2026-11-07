from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODEL_PATH = ROOT / "models" / "gesture_rf.joblib"

FS = 50         # Hz
WINDOW = 25     # 0.5 s (a shorter window reacts faster to a gesture change)
STEP = 5        # one decision every 100 ms
MEDIAN_N = 5    # spike filter: median of the last 5 samples (1 = off)

# Training-time tolerance: extra noisy copies of the data (flex, acc, gyro noise levels)
AUGMENT = ((0.0, 0.0, 0.0), (40.0, 0.10, 5.0), (70.0, 0.20, 10.0))