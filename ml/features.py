import numpy as np

CHANNELS = ["flex", "ax", "ay", "az", "gx", "gy", "gz"]
STATS = ("mean", "std", "min", "max", "energy")
FEATURE_NAMES = [f"{c}_{s}" for s in STATS for c in CHANNELS + ["amag"]]  # 40 features


def extract_features(arr: np.ndarray) -> np.ndarray:
    """arr : (N, 7), colonnes dans l'ordre de CHANNELS -> vecteur de 40 features.
    Cette fonction devra être reproduite à l'identique en C sur l'ESP32."""
    amag = np.linalg.norm(arr[:, 1:4], axis=1, keepdims=True)   # norme de l'accélération
    data = np.hstack([arr, amag])                                # (N, 8)
    return np.concatenate([
        data.mean(axis=0),
        data.std(axis=0),
        data.min(axis=0),
        data.max(axis=0),
        (data ** 2).mean(axis=0),
    ])