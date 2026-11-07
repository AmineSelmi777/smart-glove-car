from pathlib import Path

import numpy as np
import pandas as pd

from .config import AUGMENT, DATA_DIR, MEDIAN_N, STEP, WINDOW
from .features import CHANNELS, extract_features
from .filters import causal_median


def build_dataset(data_dir: Path = DATA_DIR, window: int = WINDOW, step: int = STEP,
                  median_n: int = MEDIAN_N, augment=AUGMENT):
    """CSV (timestamp, flex, ax..gz, label) -> X, y, groups (groups = one session = one file).
    `augment` adds one noisy copy of every session per noise level, so the model learns to
    tolerate noisier hands than the ones it was recorded on."""
    files = sorted(Path(data_dir).rglob("*.csv"))
    if not files:
        raise SystemExit(f"No CSV found in {data_dir}")

    X, y, groups = [], [], []
    for path in files:
        df = pd.read_csv(path)
        missing = set(CHANNELS + ["label"]) - set(df.columns)
        if missing:
            raise SystemExit(f"{path.name}: missing columns {sorted(missing)}")

        base = df[CHANNELS].to_numpy(dtype=float)
        label = str(df["label"].iloc[0])
        rng = np.random.default_rng(0)
        for flex_s, acc_s, gyro_s in augment:
            noise = np.array([flex_s, acc_s, acc_s, acc_s, gyro_s, gyro_s, gyro_s])
            arr = causal_median(base + rng.normal(0.0, 1.0, base.shape) * noise, median_n)
            for start in range(0, len(arr) - window + 1, step):
                X.append(extract_features(arr[start:start + window]))
                y.append(label)
                groups.append(path.stem)

    return np.array(X), np.array(y), np.array(groups)