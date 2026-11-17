"""
AgriNexus AI FastAPI app.

Mounts Module 1 (Farmer + AI Agriculture), Module 2 (Marketplace) and
Module 3 (Communication + Community) routers.

Run for development with: uvicorn app.main:app --reload
"""
import os

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DataError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import (
    users,
    farms,
    crops,
    disease_detection,
    pest_detection,
    crop_recommendations,
    weather,
    farmer_feedback,
    buyers,
    categories,
    listings,
    orders,
    products,
    reviews,
    suppliers,
    chat,
    community,
    issue_reports,
)

app = FastAPI(
    title="AgriNexus AI",
    description="Farmer + AI agriculture (Module 1), Marketplace (Module 2) and Communication + Community (Module 3).",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs(settings.upload_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

app.include_router(users.router)
app.include_router(farms.router)
app.include_router(crops.router)
app.include_router(disease_detection.router)
app.include_router(pest_detection.router)
app.include_router(crop_recommendations.router)
app.include_router(weather.router)
app.include_router(farmer_feedback.router)

# Module 2 - Marketplace
for _r in (buyers, categories, listings, orders, products, reviews, suppliers):
    app.include_router(_r.router)

# Module 3 - Communication + Community
for _r in (chat, community, issue_reports):
    app.include_router(_r.router)


@app.exception_handler(DataError)
async def invalid_value_handler(request: Request, exc: DataError):
    """Malformed ids (e.g. /api/suppliers/not-a-uuid) are a client error, not a 500."""
    return JSONResponse(status_code=422, content={"detail": "Invalid identifier or value"})


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok", "modules": ["farmer-ai", "marketplace", "community"]}
