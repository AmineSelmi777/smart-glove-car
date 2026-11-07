"""Optional tolerance layer between the raw Random Forest output and the car command."""
from collections import deque
from dataclasses import dataclass

STOP_GESTURES = {"closed_hand", "unknown"}
FAST_STOP = {"closed_hand"}  # explicit stop gesture: accepted at once when the model is sure


@dataclass
class Tolerance:
    avg_windows: int = 1             # average the probabilities of the last k windows
    enter_conf: float = 0.70         # confidence needed to START a moving gesture
    keep_conf: float = 0.70          # confidence needed to KEEP the current gesture (hysteresis)
    go_confirm: int = 1              # consecutive windows before a moving gesture starts
    stop_enter_conf: float = 0.70    # confidence needed to switch to a stop gesture
    stop_confirm: int = 1            # stop gestures are accepted at once
    stop_instant_conf: float = 1.1   # a single window this sure of closed_hand stops immediately (>1 = off)


# Presets. The defaults above equal OFF: the plain confidence threshold used so far.
OFF = Tolerance()
MILD = Tolerance(avg_windows=2, enter_conf=0.75, keep_conf=0.60, go_confirm=1,
                 stop_enter_conf=0.60, stop_instant_conf=0.90)
STRONG = Tolerance(avg_windows=3, enter_conf=0.80, keep_conf=0.60, go_confirm=3,
                   stop_enter_conf=0.60, stop_instant_conf=0.90)


class Stabilizer:
    """Fast to stop, slow to go: stop gestures win quickly, moving gestures must be confirmed."""

    def __init__(self, tol: Tolerance | None = None) -> None:
        self.tol = tol or OFF
        self.history: deque = deque(maxlen=self.tol.avg_windows)
        self.current = "unknown"
        self._pending: str | None = None
        self._count = 0

    def _set(self, gesture: str) -> None:
        self.current = gesture
        self._pending, self._count = None, 0

    def _avg(self) -> dict[str, float]:
        n = len(self.history)
        return {k: sum(h.get(k, 0.0) for h in self.history) / n for k in self.history[-1]}

    def update(self, proba: dict[str, float]) -> tuple[str, float]:
        """Feed one raw probability vector. Returns (stable gesture, its averaged probability)."""
        t = self.tol
        self.history.append(proba)
        avg = self._avg()

        raw_top, raw_p = max(proba.items(), key=lambda kv: kv[1])
        if raw_top in FAST_STOP and raw_p >= t.stop_instant_conf:
            self._set(raw_top)
            return self.current, avg.get(self.current, 0.0)

        # hysteresis: the current gesture survives while its own probability stays above keep_conf
        if self.current != "unknown" and avg.get(self.current, 0.0) < t.keep_conf:
            self._set("unknown")

        top, p_top = max(avg.items(), key=lambda kv: kv[1])
        if top != self.current:
            is_stop = top in STOP_GESTURES
            need = t.stop_enter_conf if is_stop else t.enter_conf
            if p_top >= need:
                self._count = self._count + 1 if self._pending == top else 1
                self._pending = top
                if self._count >= (t.stop_confirm if is_stop else t.go_confirm):
                    self._set(top)
            else:
                self._pending, self._count = None, 0
        else:
            self._pending, self._count = None, 0
        return self.current, avg.get(self.current, 0.0)