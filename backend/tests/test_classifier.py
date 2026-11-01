from app.classifier import RuleClassifier
from app.schemas import Gesture, Sample


def window(flex, a):
    return [Sample(dt=0, f=[flex] * 5, a=a, g=[0, 0, 0]) for _ in range(30)]


def test_gestes():
    c = RuleClassifier()
    assert c.predict(window(3200, [0.1, 0.05, 0.98]))[0] == Gesture.OPEN_HAND
    assert c.predict(window(4100, [0.1, 0.05, 0.98]))[0] == Gesture.CLOSED_HAND
    assert c.predict(window(3200, [-0.7, 0.05, 0.7]))[0] == Gesture.TURN_LEFT
    assert c.predict(window(3200, [0.7, 0.05, 0.7]))[0] == Gesture.TURN_RIGHT
    assert c.predict(window(3500, [0.0, 0.0, 0.2]))[0] == Gesture.UNKNOWN