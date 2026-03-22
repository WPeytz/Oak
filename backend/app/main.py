from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import connections, dashboard, goals, health, transactions, tree, users
from app.db.base import Base
from app.db.session import engine

# Import all models so Base.metadata knows about them
import app.models  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup (safe if they already exist)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(title="Oak API", version="0.1.0", lifespan=lifespan)

app.include_router(health.router)
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(goals.router, prefix="/api/goals", tags=["goals"])
app.include_router(
    connections.router, prefix="/api/connections", tags=["connections"]
)
app.include_router(
    transactions.router, prefix="/api/transactions", tags=["transactions"]
)
app.include_router(tree.router, prefix="/api/tree", tags=["tree"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["dashboard"])
