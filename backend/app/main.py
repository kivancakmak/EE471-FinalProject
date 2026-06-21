from contextlib import asynccontextmanager
import logging

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .groq_client import GroqClient
from .schemas import WeeklyPlanRequest, WeeklyPlanResponse

load_dotenv()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(
    title="NutriTrack AI Backend",
    version="0.1.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/v1/nutrition/weekly-plan", response_model=WeeklyPlanResponse)
async def weekly_plan(request: WeeklyPlanRequest) -> WeeklyPlanResponse:
    try:
        return await GroqClient().create_weekly_plan(request)
    except (RuntimeError, ValueError, KeyError) as error:
        logger.exception("Haftalık AI planı üretilemedi: %s", error)
        raise HTTPException(status_code=502, detail=str(error)) from error
