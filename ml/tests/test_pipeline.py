from ml.pipeline import GlovePipeline


def proba(open_hand=0.01, closed_hand=0.01):
    return {"open_hand": open_hand, "closed_hand": closed_hand, "turn_left": 0.01,
            "turn_right": 0.01, "unknown": 0.02}


ROW = [3200, 0.1, 0.05, 0.98, 0.0, 0.0, 0.0]


def run(predict, n_rows):
    pipe = GlovePipeline(predict)
    outs = []
    for _ in range(n_rows):
        o = pipe.push(ROW)
        if o:
            outs.append(o)
    return outs


def test_no_output_until_the_window_is_full():
    pipe = GlovePipeline(lambda arr: proba(open_hand=0.95))
    for _ in range(pipe.window - 1):
        assert pipe.push(ROW) is None
    assert pipe.push(ROW) is not None


def test_speed_ramps_up_instead_of_jumping():
    outs = run(lambda arr: proba(open_hand=0.95), 150)
    forward = [o.speed for o in outs if o.command == "FORWARD"]
    assert forward[0] <= 60
    assert all(b - a <= 60 for a, b in zip(forward, forward[1:]))
    assert forward[-1] == 255


def test_stop_gesture_gives_speed_zero():
    outs = run(lambda arr: proba(closed_hand=0.95), 100)
    assert outs and all(o.command == "STOP" and o.speed == 0 for o in outs)