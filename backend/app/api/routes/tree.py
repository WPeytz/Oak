import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.tree_service import TreeService
from app.services.user_service import UserService

router = APIRouter()


class TreeStateResponse(BaseModel):
    health_score: int
    tree_state: str
    leaf_density: float
    stress_level: float
    dominant_spending_category: str | None = None
    explanation: str
    date: date

    model_config = {"from_attributes": True}


@router.get("/{user_id}/current", response_model=TreeStateResponse | None)
async def get_current_tree(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    tree_svc = TreeService(db)
    state = await tree_svc.get_current(user_id)
    if not state:
        return None
    return state


@router.get("/{user_id}/history", response_model=list[TreeStateResponse])
async def get_tree_history(
    user_id: uuid.UUID,
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    tree_svc = TreeService(db)
    history = await tree_svc.get_history(
        user_id, from_date=from_date, to_date=to_date
    )
    return history
