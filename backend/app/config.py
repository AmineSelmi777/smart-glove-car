from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path

MODEL_PATH = Path(__file__).resolve().parents[1] / "models" / "gesture_rf.joblib"

class Settings(BaseSettings):
    classifier: str = "rule"   # "rule" ou "rf" (variable d'environnement CLASSIFIER)
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mqtt_host: str = "localhost"
    mqtt_port: int = 1883

    # Appairage fixe pour l'instant (viendra de la base plus tard)
    glove_id: str = "glove-01"
    light_id: str = "light-01"
    car_id: str = "car-01"

    window_size: int = 50          # 1 s à 50 Hz
    min_window: int = 25           # on prédit dès 0,5 s de données
    command_period_s: float = 0.3  # re-publication de la commande (CONTRATS §5)
    glove_timeout_s: float = 1.0   # gant silencieux > 1 s => STOP
    default_speed: int = 150


settings = Settings()