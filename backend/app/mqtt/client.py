import logging
import math
import threading
import time
from collections import deque

import paho.mqtt.client as mqtt
from pydantic import ValidationError

from ..classifier import Classifier
from ..config import settings
from ..decision import decide
from ..schemas import (
    CarCommand, DeviceStatus, Gesture, LightColor, LightState, SensorBatch,
)

log = logging.getLogger("backend.mqtt")


class BackendService:
    """Reçoit capteurs/feu, classe le geste, décide, publie la commande."""

    def __init__(self, classifier: Classifier) -> None:
        self.classifier = classifier
        self._lock = threading.Lock()
        self._stop = threading.Event()

        self._window: deque = deque(maxlen=settings.window_size)
        self._gesture = Gesture.UNKNOWN
        self._confidence = 0.0
        self._glove_online = False
        self._last_batch = 0.0
        self._light = LightColor.UNKNOWN
        self._light_rx = 0.0

        self._cmd_counter = 0
        self._last_logged: tuple | None = None

        self._client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="backend")
        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message

    # ---------- cycle de vie ----------
    def start(self) -> None:
        self._client.connect_async(settings.mqtt_host, settings.mqtt_port, keepalive=30)
        self._client.loop_start()
        threading.Thread(target=self._tick_loop, daemon=True).start()

    def stop(self) -> None:
        self._stop.set()
        self._client.loop_stop()
        self._client.disconnect()

    # ---------- MQTT ----------
    def _on_connect(self, client, userdata, flags, reason_code, properties) -> None:
        log.info("Connecté au broker (%s)", reason_code)
        client.subscribe([
            (f"glove/{settings.glove_id}/sensors", 0),
            (f"glove/{settings.glove_id}/status", 1),
            (f"traffic/{settings.light_id}/light", 1),
        ])

    def _on_message(self, client, userdata, msg) -> None:
        try:
            topic = msg.topic
            if topic.endswith("/sensors"):
                self._handle_sensors(msg.payload)
            elif topic.startswith("glove/") and topic.endswith("/status"):
                self._handle_glove_status(msg.payload)
            elif topic.startswith("traffic/") and topic.endswith("/light"):
                self._handle_light(msg.payload)
        except ValidationError as e:
            log.warning("Message invalide sur %s : %s", msg.topic, e.errors()[0]["msg"])
        except Exception:
            log.exception("Erreur de traitement sur %s", msg.topic)

    def _handle_sensors(self, payload: bytes) -> None:
        batch = SensorBatch.model_validate_json(payload)
        with self._lock:
            self._window.extend(batch.samples)
            self._last_batch = time.time()
            if len(self._window) >= settings.min_window:
                self._gesture, self._confidence = self.classifier.predict(list(self._window))

    def _handle_glove_status(self, payload: bytes) -> None:
        status = DeviceStatus.model_validate_json(payload)
        with self._lock:
            self._glove_online = status.state == "online"
            if not self._glove_online:
                self._window.clear()
                self._gesture, self._confidence = Gesture.UNKNOWN, 0.0

    def _handle_light(self, payload: bytes) -> None:
        light = LightState.model_validate_json(payload)
        with self._lock:
            self._light = light.color
            self._light_rx = time.time()  # horloge du backend, pas celle du feu

    # ---------- décision ----------
    def _tick_loop(self) -> None:
        while not self._stop.wait(settings.command_period_s):
            try:
                self._publish_command()
            except Exception:
                log.exception("Erreur dans la boucle de commande")

    def _publish_command(self) -> None:
        now = time.time()
        with self._lock:
            glove_ok = self._glove_online and (now - self._last_batch) <= settings.glove_timeout_s
            light_age = (now - self._light_rx) if self._light_rx else math.inf
            command, reason = decide(
                self._gesture, self._confidence, self._light, light_age, glove_ok
            )
            self._cmd_counter += 1
            cmd = CarCommand(
                ts=int(now * 1000),
                command=command,
                speed=settings.default_speed,
                reason=reason,
                cmd_id=f"c-{self._cmd_counter:06d}",
            )

        self._client.publish(f"car/{settings.car_id}/command", cmd.model_dump_json(), qos=1)

        # on ne journalise que les changements
        key = (command, reason)
        if key != self._last_logged:
            log.info("Commande : %s (%s)", command.value, reason)
            self._last_logged = key

    # ---------- état (pour /state) ----------
    def snapshot(self) -> dict:
        with self._lock:
            return {
                "glove_online": self._glove_online,
                "gesture": self._gesture.value,
                "confidence": self._confidence,
                "light": self._light.value,
                "window_samples": len(self._window),
            }