"""Faux dataset (1 flex + IMU) au format CSV du contrat. POUR TESTER LA CHAÎNE UNIQUEMENT."""
import random
import time

from .config import DATA_DIR, FS

OUT = DATA_DIR / "fake"
DUREE_S = 20
SESSIONS = 5

# Valeurs INVENTÉES : flex en ADC (croît avec la flexion), accélération en g
PROFILS = {
    "open_hand":   {"flex": 3200, "acc": (0.10, 0.05, 0.98)},
    "closed_hand": {"flex": 3900, "acc": (0.10, 0.05, 0.98)},
    "turn_left":   {"flex": 3200, "acc": (-0.70, 0.05, 0.70)},
    "turn_right":  {"flex": 3200, "acc": (0.70, 0.05, 0.70)},
}


def clamp_adc(v: float) -> int:
    return max(0, min(4095, int(v)))


def sample(gesture: str, offset: float):
    if gesture == "unknown":   # mouvements quelconques : orientation aléatoire, gyroscope agité
        return (clamp_adc(random.uniform(3200, 3900)),
                [random.uniform(-1, 1) for _ in range(3)],
                [random.gauss(0, 40) for _ in range(3)])
    p = PROFILS[gesture]
    return (clamp_adc(p["flex"] + offset + random.gauss(0, 25)),
            [v + random.gauss(0, 0.02) for v in p["acc"]],
            [random.gauss(0, 0.5) for _ in range(3)])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    t0 = int(time.time() * 1000)
    for gesture in [*PROFILS, "unknown"]:
        for k in range(SESSIONS):
            offset = random.gauss(0, 60)   # simule une main différente par session
            path = OUT / f"{gesture}_fake-{k + 1:02d}_{t0}.csv"
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write("timestamp,flex,ax,ay,az,gx,gy,gz,label\n")
                for i in range(DUREE_S * FS):
                    flex, a, g = sample(gesture, offset)
                    row = [t0 + i * 1000 // FS, flex,
                           *(round(v, 3) for v in a), *(round(v, 2) for v in g), gesture]
                    fh.write(",".join(map(str, row)) + "\n")
    print(f"CSV écrits dans {OUT}")


if __name__ == "__main__":
    main()