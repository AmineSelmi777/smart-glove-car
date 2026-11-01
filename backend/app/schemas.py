from enum import StrEnum
from pydantic import BaseModel, Field, conint
from typing import Literal


class Gesture(StrEnum):
    OPEN_HAND = "open_hand"
    CLOSED_HAND = "closed_hand"
    TURN_LEFT = "turn_left"
    TURN_RIGHT = "turn_right"
    UNKNOWN = "unknown"


class Command(StrEnum):
    FORWARD = "FORWARD"
    STOP = "STOP"
    TURN_LEFT = "TURN_LEFT"
    TURN_RIGHT = "TURN_RIGHT"


class LightColor(StrEnum):
    GREEN = "GREEN"
    RED = "RED"
    UNKNOWN = "unknown"


class Sample(BaseModel):
    dt: int = Field(ge=0)
    f: list[conint(ge=0, le=4095)] = Field(min_length=5, max_length=5)
    a: list[float] = Field(min_length=3, max_length=3)
    g: list[float] = Field(min_length=3, max_length=3)


class SensorBatch(BaseModel):
    v: int = 1
    device: str
    seq: int
    fs: int = 50
    ts: int
    samples: list[Sample] = Field(min_length=1, max_length=50)


class CarCommand(BaseModel):
    v: int = 1
    ts: int
    command: Command
    speed: int = Field(default=150, ge=0, le=255)
    reason: str
    cmd_id: str

class LightState(BaseModel):
    v: int = 1
    device: str
    ts: int
    color: LightColor


class DeviceStatus(BaseModel):
    v: int = 1
    device: str
    state: Literal["online", "offline"]
    ts: int | None = None  # le Last Will n'a pas de ts