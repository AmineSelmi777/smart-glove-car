import numpy as np


def causal_median(arr: np.ndarray, n: int) -> np.ndarray:
    """Median of the last n rows for every row (n = 1 means no filtering).
    Removes isolated spikes; the first rows use the rows available so far."""
    if n <= 1:
        return arr
    out = np.empty_like(arr, dtype=float)
    for i in range(len(arr)):
        out[i] = np.median(arr[max(0, i - n + 1): i + 1], axis=0)
    return out