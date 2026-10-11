import pytest
from app.decision import decide
from app.schemas import Command, Gesture, LightColor

G, R = LightColor.GREEN, LightColor.RED


@pytest.mark.parametrize(
    "gesture, conf, light, age, online, expected",
    [
        (Gesture.OPEN_HAND, 0.9, G, 1.0, True, Command.FORWARD),
        (Gesture.TURN_LEFT, 0.9, G, 1.0, True, Command.TURN_LEFT),
        (Gesture.TURN_RIGHT, 0.9, G, 1.0, True, Command.TURN_RIGHT),
        (Gesture.OPEN_HAND, 0.9, R, 1.0, True, Command.STOP),       # feu rouge
        (Gesture.CLOSED_HAND, 0.9, G, 1.0, True, Command.STOP),     # poing
        (Gesture.OPEN_HAND, 0.5, G, 1.0, True, Command.STOP),       # confiance faible
        (Gesture.UNKNOWN, 0.95, G, 1.0, True, Command.STOP),        # geste inconnu
        (Gesture.OPEN_HAND, 0.9, G, 9.0, True, Command.STOP),       # feu périmé
        (Gesture.OPEN_HAND, 0.9, LightColor.UNKNOWN, 0, True, Command.STOP),
        (Gesture.OPEN_HAND, 0.9, G, 1.0, False, Command.STOP),      # gant perdu
    ],
)
def test_decide(gesture, conf, light, age, online, expected):
    cmd, _reason = decide(gesture, conf, light, age, online)
    assert cmd == expected 