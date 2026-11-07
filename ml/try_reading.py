import argparse

from .inference import Predictor, predict_reading


def main() -> None:
    ap = argparse.ArgumentParser(description="Classify one sensor reading (repeated into a window).")
    for name in ("flex", "ax", "ay", "az", "gx", "gy", "gz"):
        ap.add_argument(name, type=float)
    a = ap.parse_args()
    reading = [a.flex, a.ax, a.ay, a.az, a.gx, a.gy, a.gz]
    for label, p in sorted(predict_reading(Predictor(), reading).items(), key=lambda kv: -kv[1]):
        print(f"{label:12s} {p:6.1%}")


if __name__ == "__main__":
    main()