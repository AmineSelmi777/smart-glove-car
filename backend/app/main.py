import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .classifier import RuleClassifier,SklearnClassifier
from .mqtt.client import BackendService
from .config import MODEL_PATH, settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    classifier = SklearnClassifier(MODEL_PATH) if settings.classifier == "rf" else RuleClassifier()
    logging.getLogger("backend").info("Classifieur actif : %s", type(classifier).__name__)
    service = BackendService(classifier)
    
    service.start()
    app.state.service = service
    yield
    service.stop()


app = FastAPI(title="Gant intelligent - Backend", version="0.2.0", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/state")
def state():
    return app.state.service.snapshot()