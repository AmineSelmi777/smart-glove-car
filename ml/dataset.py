from pathlib import Path

import numpy as np
import pandas as pd

from .config import DATA_DIR, STEP, WINDOW
from .features import CHANNELS, extract_features


def build_dataset(data_dir: Path = DATA_DIR, window: int = WINDOW, step: int = STEP):
    """CSV (timestamp, flex, ax..gz, label) -> X, y, groups (groups = une session)."""
    files = sorted(Path(data_dir).rglob("*.csv"))
    if not files:
        raise SystemExit(f"Aucun CSV trouvé dans {data_dir}")

    X, y, groups = [], [], []
    for path in files:
        df = pd.read_csv(path)
        manquantes = set(CHANNELS + ["label"]) - set(df.columns)
        if manquantes:
            raise SystemExit(f"{path.name} : colonnes manquantes {sorted(manquantes)}")

        arr = df[CHANNELS].to_numpy(dtype=float)
        label = str(df["label"].iloc[0])
        for start in range(0, len(arr) - window + 1, step):
            X.append(extract_features(arr[start:start + window]))
            y.append(label)
            groups.append(path.stem)

    return np.array(X), np.array(y), np.array(groups)