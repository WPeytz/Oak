from fastapi import FastAPI

from app.api.routes import connections, dashboard, goals, health, transactions, tree, users

app = FastAPI(title="Oak API", version="0.1.0")

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
