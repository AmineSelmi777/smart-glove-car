from .schemas import Command, Gesture, LightColor

CONFIDENCE_MIN = 0.70
LIGHT_MAX_AGE_S = 5.0


def decide(
    gesture: Gesture,
    confidence: float,
    light: LightColor,
    light_age_s: float,
    glove_online: bool = True,
) -> tuple[Command, str]:
    """Retourne (commande, raison). En cas de doute : STOP."""
    if not glove_online:
        return Command.STOP, "glove_lost"
    if confidence < CONFIDENCE_MIN:
        return Command.STOP, "low_confidence"
    if gesture == Gesture.UNKNOWN:
        return Command.STOP, "unknown_gesture"
    if light == LightColor.UNKNOWN or light_age_s > LIGHT_MAX_AGE_S:
        return Command.STOP, "light_unknown"
    if gesture == Gesture.CLOSED_HAND:
        return Command.STOP, "closed_hand"
    if light == LightColor.RED:
        return Command.STOP, "red_light"

    moves = {
        Gesture.OPEN_HAND: Command.FORWARD,
        Gesture.TURN_LEFT: Command.TURN_LEFT,
        Gesture.TURN_RIGHT: Command.TURN_RIGHT,
    }
    return moves[gesture], f"{gesture.value}+GREEN"