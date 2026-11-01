from pathlib import Path

import numpy as np
import pandas as pd

from .features import CHANNELS, extract_features

DATA_DIR = Path(__file__).resolve().parents[3] / "data"   # C:\projet-gant\data
WINDOW = 50   # 1 s à 50 Hz
STEP = 10     # pas de 200 ms


def build_dataset(data_dir: Path = DATA_DIR, window: int = WINDOW, step: int = STEP):
    """Lit tous les CSV (format CONTRATS §11) et retourne X, y, groups.
    groups = nom du fichier : sert à ne jamais mélanger une même session entre train et test."""
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