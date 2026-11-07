"""Replays a scripted scenario through the whole chain and compares tolerance presets.

    python -m ml.chain_demo --scenario clean|spikes|shaky [--seeds 8] [--raw-speed]
"""
import argparse
import math
import random

import numpy as np

from .config import FS
from .fake_dataset import sample
from .inference import Predictor
from .pipeline import DEFAULT_MAPPING, GlovePipeline, SpeedTolerance
from .stabilizer import MILD, OFF, STRONG

SCENARIO = [("open_hand", 4.0), ("turn_left", 4.0), ("closed_hand", 4.0),
            ("turn_right", 4.0), ("open_hand", 4.0)]
BLEND_S = 0.4   # time to move from one gesture to the next
LETTER = {"FORWARD": "F", "TURN_LEFT": "L", "TURN_RIGHT": "R", "STOP": "."}
PRESETS = {"off": OFF, "mild": MILD, "strong": STRONG}


def build_scenario(seed: int = 1, kind: str = "clean"):
    """Rows [flex, ax, ay, az, gx, gy, gz], expected gesture per row, segment boundaries."""
    random.seed(seed)
    offset = random.gauss(0, 60)
    rows, truth, bounds = [], [], []
    for k, (gesture, secs) in enumerate(SCENARIO):
        prev = SCENARIO[k - 1][0] if k else None
        bounds.append(len(rows))
        for j in range(int(secs * FS)):
            f, a, g = sample(gesture, offset)
            openness = 0.0 if gesture == "closed_hand" else 1.0
            if prev and j < BLEND_S * FS:
                alpha = (j + 1) / (BLEND_S * FS)
                f0, a0, g0 = sample(prev, offset)
                f = (1 - alpha) * f0 + alpha * f
                a = [(1 - alpha) * x + alpha * y for x, y in zip(a0, a)]
                g = [(1 - alpha) * x + alpha * y for x, y in zip(g0, g)]
                open0 = 0.0 if prev == "closed_hand" else 1.0
                openness = (1 - alpha) * open0 + alpha * openness
            i = len(rows)
            f += openness * 250 * 0.5 * (1 + math.sin(2 * math.pi * i / FS / 6))  # slow finger movement
            rows.append([f, *a, *g])
            truth.append(gesture)
    bounds.append(len(rows))
    rows = np.array(rows)

    rng = np.random.default_rng(seed + 7)
    if kind == "spikes":      # isolated sensor glitches (about 1 sample in 250)
        for i in range(len(rows)):
            if rng.random() < 0.004:
                rows[i, 0] += rng.choice([-1, 1]) * rng.uniform(300, 800)
                rows[i, 1:4] += rng.uniform(-1.5, 1.5, 3)
                rows[i, 4:7] += rng.normal(0, 150, 3)
    elif kind == "shaky":     # a noisier hand than the one the model was trained on
        rows[:, 0] += rng.normal(0, 70, len(rows))
        rows[:, 1:4] += rng.normal(0, 0.20, (len(rows), 3))
        rows[:, 4:7] += rng.normal(0, 10, (len(rows), 3))
    return rows, truth, bounds


def run(predictor, rows, **cfg):
    pipe = GlovePipeline(predictor.predict_proba, **cfg)
    outs = []
    for i, row in enumerate(rows):
        out = pipe.push(row)
        if out:
            outs.append((i, out))
    return outs


def metrics(outs, truth, bounds):
    per = (outs[1][0] - outs[0][0]) / FS
    seg_of = {i: k for k in range(len(bounds) - 1) for i in range(bounds[k], bounds[k + 1])}
    danger = spurious = max_jump = 0.0
    prev = None
    for i, o in outs:
        want = DEFAULT_MAPPING[truth[i]]
        t = (i - bounds[seg_of[i]]) / FS
        if (want == "STOP" and o.command != "STOP") or (want != "STOP" and o.command not in ("STOP", want)):
            danger += per                     # moving when it should stop, or turning the wrong way
        if want != "STOP" and o.command == "STOP" and t >= 1.8:
            spurious += per                   # stopped although the gesture was held for a while
        if prev is not None and o.command != "STOP":
            max_jump = max(max_jump, abs(o.speed - prev.speed))   # includes the start from a standstill
        prev = o
    changes = sum(1 for (_, a), (_, b) in zip(outs, outs[1:]) if a.command != b.command)

    go, stop = [], None
    for k in range(1, len(SCENARIO)):
        want = DEFAULT_MAPPING[SCENARIO[k][0]]
        seg = [(i, o) for i, o in outs if bounds[k] <= i < bounds[k + 1]]
        t = next(((seg[x][0] - bounds[k]) / FS for x in range(len(seg))
                  if all(o.command == want for _, o in seg[x:])), None)
        if SCENARIO[k][0] == "closed_hand":
            stop = t
        elif t is not None:
            go.append(t)
    return dict(changes=changes, danger=danger, spurious=spurious,
                go=float(np.mean(go)) if go else float("nan"),
                stop=stop if stop is not None else float("nan"), jump=max_jump)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", choices=["clean", "spikes", "shaky"], default="clean")
    ap.add_argument("--seeds", type=int, default=8)
    ap.add_argument("--raw-speed", action="store_true", help="disable the speed smoothing")
    args = ap.parse_args()

    speed_tol = SpeedTolerance(ema_alpha=1.0, deadband=0, max_rise=255) if args.raw_speed else SpeedTolerance()
    predictor = Predictor()
    print("Scenario:", " -> ".join(f"{g} {s:.0f}s" for g, s in SCENARIO), f"| noise: {args.scenario}")

    rows, truth, bounds = build_scenario(1, args.scenario)
    first = run(predictor, rows, tol=OFF, speed_tol=speed_tol)
    print("\nOne letter per decision  (F forward, L left, R right, . stop), seed 1")
    print(f"{'expected':9s} " + "".join(LETTER[DEFAULT_MAPPING[truth[i]]] for i, _ in first))
    for name, tol in PRESETS.items():
        outs = run(predictor, rows, tol=tol, speed_tol=speed_tol)
        print(f"{name:9s} " + "".join(LETTER[o.command] for _, o in outs))

    print(f"\nMean over {args.seeds} scenarios")
    print(f"{'preset':8s} {'changes':>7s} {'wrong_s':>8s} {'spurious_stop_s':>16s} {'go_lat_s':>9s} "
          f"{'stop_lat_s':>11s} {'max_speed_jump':>15s}")
    for name, tol in PRESETS.items():
        ms = []
        for seed in range(1, args.seeds + 1):
            r, tr, bd = build_scenario(seed, args.scenario)
            ms.append(metrics(run(predictor, r, tol=tol, speed_tol=speed_tol), tr, bd))
        m = {k: float(np.nanmean([x[k] for x in ms])) for k in ms[0]}
        print(f"{name:8s} {m['changes']:7.1f} {m['danger']:8.2f} {m['spurious']:16.2f} {m['go']:9.2f} "
              f"{m['stop']:11.2f} {m['jump']:15.0f}")
    print("\nIdeal: changes = 5. wrong_s = time moving when it should stop or turning the wrong way.")


if __name__ == "__main__":
    main()