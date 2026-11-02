import numpy as np

from ml.features import FEATURE_NAMES, extract_features


def test_taille_du_vecteur():
    arr = np.random.rand(50, 7)
    assert len(FEATURE_NAMES) == 40
    assert extract_features(arr).shape == (40,)