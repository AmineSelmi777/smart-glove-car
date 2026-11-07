import joblib
import numpy as np

from .config import MODEL_PATH
from .features import extract_features


class Predictor:
    """Loads the trained Random Forest and turns a window of samples into class probabilities."""

    def __init__(self, path=MODEL_PATH) -> None:
        bundle = joblib.load(path)
        self.model = bundle["model"]
        self.window = bundle["window"]

    def predict_proba(self, arr: np.ndarray) -> dict[str, float]:
        """arr: (N, 7) rows [flex, ax, ay, az, gx, gy, gz] with N >= window. Uses the last `window` rows."""
        if len(arr) < self.window:
            raise ValueError(f"need at least {self.window} samples, got {len(arr)}")
        feats = extract_features(np.asarray(arr[-self.window:], dtype=float)).reshape(1, -1)
        proba = self.model.predict_proba(feats)[0]
        return {str(c): float(p) for c, p in zip(self.model.classes_, proba)}


def steady_window(reading, n: int = 50, flex_noise: float = 25.0, acc_noise: float = 0.02,
                  gyro_noise: float = 0.5, seed: int | None = None) -> np.ndarray:
    """Build a window from ONE reading (flex, ax, ay, az, gx, gy, gz) by repeating it with small noise.
    The model classifies windows, not single readings, and a perfectly constant window
    (std = 0) never occurs in real data."""
    rng = np.random.default_rng(seed)
    base = np.asarray(reading, dtype=float)
    noise = np.array([flex_noise, acc_noise, acc_noise, acc_noise, gyro_noise, gyro_noise, gyro_noise])
    return base + rng.normal(0.0, 1.0, size=(n, 7)) * noise


def predict_reading(predictor: Predictor, reading, seed: int | None = 0) -> dict[str, float]:
    """Classify ONE reading with the same preprocessing as the live pipeline (spike filter included)."""
    from .config import MEDIAN_N
    from .filters import causal_median

    win = steady_window(reading, n=predictor.window + MEDIAN_N, seed=seed)
    return predictor.predict_proba(causal_median(win, MEDIAN_N))