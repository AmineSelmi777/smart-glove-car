"""Whole decision chain: samples -> window -> model -> stabilizer -> command and speed."""
from collections import deque
from dataclasses import dataclass

import numpy as np

from .config import MEDIAN_N, STEP, WINDOW
from .speed import Calibration, flex_to_speed
from .stabilizer import OFF, Stabilizer, Tolerance

DEFAULT_MAPPING = {
    "open_hand": "FORWARD",
    "closed_hand": "STOP",
    "turn_left": "TURN_LEFT",
    "turn_right": "TURN_RIGHT",
    "unknown": "STOP",
}


@dataclass
class SpeedTolerance:
    ema_alpha: float = 0.4   # smoothing of the flex value
    deadband: int = 25       # flex changes smaller than this (ADC units) are ignored
    max_rise: int = 60       # max speed increase per decision (100 ms); slowing down is unlimited


@dataclass
class Output:
    gesture: str
    confidence: float
    command: str
    speed: int
    raw_gesture: str
    raw_confidence: float


class GlovePipeline:
    def __init__(self, predict_proba, tol: Tolerance | None = None,
                 speed_tol: SpeedTolerance | None = None, calib: Calibration | None = None,
                 mapping: dict | None = None, window: int = WINDOW, step: int = STEP,
                 median_n: int = MEDIAN_N) -> None:
        self.predict_proba = predict_proba
        self.stabilizer = Stabilizer(tol)
        self.speed_tol = speed_tol or SpeedTolerance()
        self.calib = calib or Calibration()
        self.mapping = mapping or DEFAULT_MAPPING
        self.window, self.step = window, step
        self.rows: deque = deque(maxlen=window)
        self._raw: deque = deque(maxlen=max(1, median_n))
        self._since = 0
        self._flex: float | None = None
        self._speed = 0

    def push(self, row) -> Output | None:
        """row = (flex, ax, ay, az, gx, gy, gz). Returns an Output every `step` rows once the window is full."""
        self._raw.append(row)
        self.rows.append(np.median(np.asarray(self._raw, dtype=float), axis=0))
        self._since += 1
        if len(self.rows) < self.window or self._since < self.step:
            return None
        self._since = 0

        arr = np.asarray(self.rows, dtype=float)
        proba = self.predict_proba(arr)
        raw_gesture, raw_conf = max(proba.items(), key=lambda kv: kv[1])
        gesture, conf = self.stabilizer.update(proba)
        command = self.mapping.get(gesture, "STOP")
        speed = self._speed_for(command, float(arr[-self.step:, 0].mean()))
        return Output(gesture, conf, command, speed, raw_gesture, raw_conf)

    def _speed_for(self, command: str, flex_mean: float) -> int:
        st = self.speed_tol
        if self._flex is None:
            self._flex = flex_mean
        elif abs(flex_mean - self._flex) >= st.deadband:
            self._flex = st.ema_alpha * flex_mean + (1 - st.ema_alpha) * self._flex
        if command == "STOP":
            self._speed = 0
            return 0
        target = flex_to_speed(self._flex, self.calib)
        if target > self._speed:
            self._speed = min(target, self._speed + st.max_rise)
        else:
            self._speed = target
        return self._speed