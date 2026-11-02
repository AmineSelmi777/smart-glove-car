from dataclasses import dataclass


@dataclass
class Calibration:
    open: int = 3200      # ADC main ouverte (à mesurer sur le vrai gant)
    closed: int = 3900    # ADC poing fermé
    lo: float = 0.10      # en dessous de 10 % d'ouverture : vitesse 0 (zone morte)
    hi: float = 0.90      # au-dessus de 90 % d'ouverture : vitesse max
    vmax: int = 255


def flex_to_speed(flex: float, c: Calibration = Calibration()) -> int:
    """Valeur ADC du flex -> vitesse PWM 0..vmax. Ouvert = rapide, fermé = 0."""
    span = c.closed - c.open
    if span == 0:
        return 0
    bend = min(1.0, max(0.0, (flex - c.open) / span))   # 0 = ouverte, 1 = fermée
    openness = 1.0 - bend
    x = (openness - c.lo) / (c.hi - c.lo)
    return round(min(1.0, max(0.0, x)) * c.vmax)


class Ema:
    """Filtre à moyenne exponentielle : lisse le flex avant conversion (évite les à-coups)."""
    def __init__(self, alpha: float = 0.3) -> None:
        self.alpha, self.value = alpha, None

    def update(self, x: float) -> float:
        self.value = x if self.value is None else self.alpha * x + (1 - self.alpha) * self.value
        return self.value