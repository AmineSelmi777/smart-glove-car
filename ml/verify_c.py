"""Compile the C core with gcc and check it against the Python pipeline on the chain_demo scenarios.

    python -m ml.verify_c
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

from .chain_demo import build_scenario
from .config import ROOT
from .inference import Predictor
from .pipeline import GlovePipeline

SRC = ROOT / "firmware" / "glove" / "src"
HARNESS = ROOT / "firmware" / "glove" / "test" / "native_harness.c"
COMMAND = {"STOP": 0, "FORWARD": 1, "TURN_LEFT": 2, "TURN_RIGHT": 3}


def main() -> None:
    cc = shutil.which("gcc") or shutil.which("cc")
    if not cc:
        raise SystemExit("No C compiler found. Run this in WSL/Ubuntu (sudo apt install gcc) or install MSYS2 gcc.")

    work = Path(tempfile.mkdtemp())
    exe = work / ("harness.exe" if os.name == "nt" else "harness")
    build = subprocess.run([cc, "-O2", "-std=c11", "-Wall", "-Wextra", f"-I{SRC}", str(SRC / "glove_core.c"),
                            str(HARNESS), "-lm", "-o", str(exe)], capture_output=True, text=True)
    if build.returncode != 0:
        print(build.stderr)
        raise SystemExit("C compilation failed")

    predictor = Predictor()
    classes = [str(c) for c in predictor.model.classes_]
    print(f"{'scenario':14s} {'decisions':>9s} {'gesture ok':>10s} {'command ok':>10s} "
          f"{'max speed diff':>14s} {'max conf diff':>13s}")
    worst = 0.0
    for kind in ("clean", "spikes", "shaky"):
        for seed in (1, 2, 3):
            rows, _, _ = build_scenario(seed, kind)
            rows32 = rows.astype(np.float32)
            bin_path = work / "rows.bin"
            rows32.tofile(bin_path)

            c = subprocess.run([str(exe), str(bin_path)], capture_output=True, text=True)
            if c.returncode != 0:
                raise SystemExit(f"harness failed ({c.returncode})")
            c_out = [line.split(",") for line in c.stdout.strip().splitlines()]

            pipe = GlovePipeline(predictor.predict_proba)
            py_out = []
            for i, row in enumerate(rows32.astype(float)):     # same float32-rounded input for both sides
                o = pipe.push(row)
                if o:
                    py_out.append((i, classes.index(o.gesture), o.confidence, COMMAND[o.command], o.speed))

            if len(py_out) != len(c_out):
                raise SystemExit(f"{kind}/{seed}: {len(py_out)} Python decisions but {len(c_out)} C decisions")
            g_ok = np.mean([int(a[1]) == b[1] for a, b in zip(c_out, py_out)])
            c_ok = np.mean([int(a[3]) == b[3] for a, b in zip(c_out, py_out)])
            s_diff = max(abs(int(a[4]) - b[4]) for a, b in zip(c_out, py_out))
            p_diff = max(abs(float(a[2]) - b[2]) for a, b in zip(c_out, py_out))
            worst = max(worst, 1 - g_ok, 1 - c_ok)
            print(f"{kind + ' #' + str(seed):14s} {len(py_out):9d} {g_ok:10.1%} {c_ok:10.1%} "
                  f"{s_diff:14d} {p_diff:13.4f}")

    shutil.rmtree(work, ignore_errors=True)
    if worst > 0.005:
        print("\nMISMATCH: the C core and the Python pipeline disagree.")
        sys.exit(1)
    print("\nOK: the C core reproduces the Python pipeline.")


if __name__ == "__main__":
    main()