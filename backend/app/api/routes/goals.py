import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.goals import GoalResponse, UpsertGoalRequest
from app.db.session import get_db
from app.services.goal_service import GoalService
from app.services.user_service import UserService

router = APIRouter()


@router.put("/{user_id}", response_model=GoalResponse)
async def upsert_goal(
    user_id: uuid.UUID,
    body: UpsertGoalRequest,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    goal_svc = GoalService(db)
    goal = await goal_svc.upsert(
        user_id=user_id,
        monthly_discretionary_budget=body.monthly_discretionary_budget,
        monthly_savings_target=body.monthly_savings_target,
        monthly_net_goal=body.monthly_net_goal,
    )
    await db.commit()
    return goal


@router.get("/{user_id}", response_model=GoalResponse)
async def get_goal(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    goal_svc = GoalService(db)
    goal = await goal_svc.get_for_user(user_id)
    if not goal:
        raise HTTPException(status_code=404, detail="No spending goal set")
    return goal
