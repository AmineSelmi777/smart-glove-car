from ml.stabilizer import STRONG, Stabilizer


def p(**kw):
    base = {"open_hand": 0.01, "closed_hand": 0.01, "turn_left": 0.01, "turn_right": 0.01, "unknown": 0.01}
    base.update(kw)
    return base


OPEN = p(open_hand=0.95)
CLOSED = p(closed_hand=0.92)


def settled_on_open():
    s = Stabilizer(STRONG)
    for _ in range(3):
        s.update(OPEN)
    return s


def test_moving_gesture_needs_three_confirmations():
    s = Stabilizer(STRONG)
    s.update(OPEN)
    assert s.current == "unknown"
    s.update(OPEN)
    assert s.current == "unknown"
    s.update(OPEN)
    assert s.current == "open_hand"


def test_short_dip_keeps_the_gesture():
    s = settled_on_open()
    s.update(p(open_hand=0.5, turn_left=0.4))
    assert s.current == "open_hand"


def test_gesture_is_lost_when_evidence_fades():
    s = settled_on_open()
    weak = p(open_hand=0.4, turn_left=0.3, closed_hand=0.2)
    for _ in range(3):
        s.update(weak)
    assert s.current == "unknown"


def test_closed_hand_stops_immediately():
    s = settled_on_open()
    s.update(CLOSED)
    assert s.current == "closed_hand"