"""Simulateur de gant : publie des lots de capteurs sur MQTT (voir CONTRATS.md)."""
import argparse
import json
import random
import time

import paho.mqtt.client as mqtt

FS = 50            # Hz
BATCH = 10         # échantillons par message (200 ms)

# Valeurs typiques (flex ADC, accélération x/y/z en g) par geste
PROFILES = {
    "open_hand":   {"flex": 3200, "acc": (0.10, 0.05, 0.98)},
    "closed_hand": {"flex": 4100, "acc": (0.10, 0.05, 0.98)},
    "turn_left":   {"flex": 3200, "acc": (-0.70, 0.05, 0.70)},
    "turn_right":  {"flex": 3200, "acc": (0.70, 0.05, 0.70)},
}


def make_sample(gesture: str, dt: int) -> dict:
    p = PROFILES[gesture]
    return {
        "dt": dt,
        "f": [int(p["flex"] + random.gauss(0, 25)) for _ in range(5)],
        "a": [round(v + random.gauss(0, 0.02), 3) for v in p["acc"]],
        "g": [round(random.gauss(0, 0.5), 2) for _ in range(3)],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="glove-01")
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--sequence", default="open_hand",
                    help="gestes séparés par des virgules, ex: open_hand,turn_left,closed_hand")
    ap.add_argument("--hold", type=float, default=3.0,
                    help="secondes avant de passer au geste suivant")
    args = ap.parse_args()

    sequence = [g.strip() for g in args.sequence.split(",")]
    for g in sequence:
        if g not in PROFILES:
            raise SystemExit(f"Geste inconnu : {g} (choix : {', '.join(PROFILES)})")

    topic_sensors = f"glove/{args.device}/sensors"
    topic_status = f"glove/{args.device}/status"

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=args.device)
    # Last Will : le broker publie "offline" si le simulateur s'arrête brutalement
    client.will_set(topic_status, json.dumps({"v": 1, "device": args.device, "state": "offline"}),
                    qos=1, retain=True)
    client.connect(args.host, args.port, keepalive=10)
    client.loop_start()

    client.publish(topic_status, json.dumps(
        {"v": 1, "device": args.device, "state": "online", "ts": int(time.time() * 1000)}),
        qos=1, retain=True)

    print(f"[{args.device}] publie sur {topic_sensors} - séquence : {sequence} (Ctrl+C pour arrêter)")

    seq = 0
    idx = 0
    gesture_started = time.monotonic()
    period = BATCH / FS
    next_t = time.monotonic()

    try:
        while True:
            now = time.monotonic()
            if now - gesture_started >= args.hold and len(sequence) > 1:
                idx = (idx + 1) % len(sequence)
                gesture_started = now
                print(f"  -> geste simulé : {sequence[idx]}")
            gesture = sequence[idx]

            msg = {
                "v": 1,
                "device": args.device,
                "seq": seq,
                "fs": FS,
                "ts": int(time.time() * 1000),
                "samples": [make_sample(gesture, i * (1000 // FS)) for i in range(BATCH)],
            }
            client.publish(topic_sensors, json.dumps(msg), qos=0)
            seq += 1

            next_t += period
            time.sleep(max(0.0, next_t - time.monotonic()))
    except KeyboardInterrupt:
        pass
    finally:
        client.publish(topic_status, json.dumps(
            {"v": 1, "device": args.device, "state": "offline", "ts": int(time.time() * 1000)}),
            qos=1, retain=True).wait_for_publish()
        client.loop_stop()
        client.disconnect()
        print("Simulateur arrêté.")


if __name__ == "__main__":
    main()