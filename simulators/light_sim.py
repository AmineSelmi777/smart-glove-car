"""Simulateur de feu tricolore : alterne GREEN / RED, heartbeat toutes les 2 s."""
import argparse
import json
import time

import paho.mqtt.client as mqtt


def now_ms() -> int:
    return int(time.time() * 1000)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="light-01")
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--green", type=float, default=15, help="durée du vert (s)")
    ap.add_argument("--red", type=float, default=8, help="durée du rouge (s)")
    args = ap.parse_args()

    topic_light = f"traffic/{args.device}/light"
    topic_status = f"traffic/{args.device}/status"

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=args.device)
    client.will_set(topic_status, json.dumps({"v": 1, "device": args.device, "state": "offline"}),
                    qos=1, retain=True)
    client.connect(args.host, args.port, keepalive=10)
    client.loop_start()
    client.publish(topic_status, json.dumps(
        {"v": 1, "device": args.device, "state": "online", "ts": now_ms()}), qos=1, retain=True)

    color, since = "GREEN", time.monotonic()
    print(f"[{args.device}] cycle : {args.green}s GREEN / {args.red}s RED (Ctrl+C pour arrêter)")
    try:
        while True:
            duration = args.green if color == "GREEN" else args.red
            if time.monotonic() - since >= duration:
                color = "RED" if color == "GREEN" else "GREEN"
                since = time.monotonic()
                print(f"  -> feu : {color}")
            client.publish(topic_light, json.dumps(
                {"v": 1, "device": args.device, "ts": now_ms(), "color": color}),
                qos=1, retain=True)
            time.sleep(2)  # heartbeat (CONTRATS §3.3)
    except KeyboardInterrupt:
        pass
    finally:
        client.publish(topic_status, json.dumps(
            {"v": 1, "device": args.device, "state": "offline", "ts": now_ms()}),
            qos=1, retain=True).wait_for_publish()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()