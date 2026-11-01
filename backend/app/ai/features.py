import numpy as np

from ..schemas import Sample

CHANNELS = ["f1", "f2", "f3", "f4", "f5", "ax", "ay", "az", "gx", "gy", "gz"]
STATS = ("mean", "std", "min", "max", "energy")
FEATURE_NAMES = [f"{c}_{s}" for s in STATS for c in CHANNELS + ["amag"]]  # 60 features


def samples_to_array(samples: list[Sample]) -> np.ndarray:
    """Liste d'échantillons -> tableau (N, 11), colonnes dans l'ordre de CHANNELS."""
    return np.array([[*s.f, *s.a, *s.g] for s in samples], dtype=float)


def extract_features(arr: np.ndarray) -> np.ndarray:
    """Tableau (N, 11) -> vecteur de 60 features. Même fonction à l'entraînement et en production."""
    amag = np.linalg.norm(arr[:, 5:8], axis=1, keepdims=True)  # norme de l'accélération
    data = np.hstack([arr, amag])                               # (N, 12)
    return np.concatenate([
        data.mean(axis=0),
        data.std(axis=0),
        data.min(axis=0),
        data.max(axis=0),
        (data ** 2).mean(axis=0),
    ])