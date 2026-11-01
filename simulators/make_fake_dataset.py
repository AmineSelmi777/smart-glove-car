"""Génère un faux dataset au format CONTRATS §11. POUR TESTER LA CHAÎNE UNIQUEMENT."""
import random
import time
from pathlib import Path

from glove_sim import make_sample

OUT = Path(__file__).resolve().parents[1] / "data" / "fake"
GESTES = ["open_hand", "closed_hand", "turn_left", "turn_right"]
SESSIONS_PAR_GESTE = 5
DUREE_S = 20
FS = 50

OUT.mkdir(parents=True, exist_ok=True)
t0 = int(time.time() * 1000)

for gesture in GESTES:
    for k in range(SESSIONS_PAR_GESTE):
        offset = random.gauss(0, 60)   # simule une main / un montage différent par session
        rows = []
        for i in range(DUREE_S * FS):
            s = make_sample(gesture, 0)
            f = [max(0, min(4095, int(v + offset))) for v in s["f"]]
            rows.append([t0 + i * 20, *f, *s["a"], *s["g"], gesture])
        path = OUT / f"{gesture}_fake-{k + 1:02d}_{t0}.csv"
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("timestamp,f1,f2,f3,f4,f5,ax,ay,az,gx,gy,gz,label\n")
            for r in rows:
                fh.write(",".join(str(v) for v in r) + "\n")

print(f"CSV écrits dans {OUT}") 