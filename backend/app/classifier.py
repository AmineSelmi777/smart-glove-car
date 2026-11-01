from statistics import fmean
from typing import Protocol

from .schemas import Gesture, Sample

import joblib
from .ai.features import samples_to_array, extract_features


class Classifier(Protocol):
    def predict(self, window: list[Sample]) -> tuple[Gesture, float]:
        """Retourne (geste, confiance) pour une fenêtre d'échantillons."""
        ...


class RuleClassifier:
    """Classifieur à seuils, pour tester le pipeline sans modèle entraîné.
    Les seuils correspondent aux valeurs INVENTÉES de glove_sim.py."""

    FLEX_CLOSED = 3550
    TILT = 0.4
    FLAT_Z = 0.8

    def predict(self, window: list[Sample]) -> tuple[Gesture, float]:
        if not window:
            return Gesture.UNKNOWN, 0.0

        flex = fmean(sum(s.f) / 5 for s in window)
        ax = fmean(s.a[0] for s in window)
        az = fmean(s.a[2] for s in window)

        if flex > self.FLEX_CLOSED:
            return Gesture.CLOSED_HAND, 0.9
        if ax < -self.TILT:
            return Gesture.TURN_LEFT, 0.9
        if ax > self.TILT:
            return Gesture.TURN_RIGHT, 0.9
        if az > self.FLAT_Z:
            return Gesture.OPEN_HAND, 0.9
        return Gesture.UNKNOWN, 0.0

class SklearnClassifier:
    """Classifieur RandomForest entraîné avec app/ai/train.py."""

    def __init__(self, path) -> None:
        bundle = joblib.load(path)
        self.model = bundle["model"]
        self.size = bundle["window"]

    def predict(self, window: list[Sample]) -> tuple[Gesture, float]:
        if len(window) < self.size:
            return Gesture.UNKNOWN, 0.0    # fenêtre incomplète : on attend
        feats = extract_features(samples_to_array(window[-self.size:])).reshape(1, -1)
        proba = self.model.predict_proba(feats)[0]
        i = int(proba.argmax())
        return Gesture(self.model.classes_[i]), float(proba[i])