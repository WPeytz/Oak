import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.savings_goal_service import SavingsGoalService
from app.services.user_service import UserService

router = APIRouter()


class CreateSavingsGoalRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    target_amount: float = Field(gt=0)


class UpdateSavingsGoalRequest(BaseModel):
    name: str | None = None
    target_amount: float | None = Field(default=None, gt=0)
    current_amount: float | None = Field(default=None, ge=0)


class SavingsGoalResponse(BaseModel):
    id: uuid.UUID
    name: str
    target_amount: float
    current_amount: float
    sort_order: int
    progress: float  # 0.0 to 1.0+

    model_config = {"from_attributes": True}


def _to_response(goal) -> SavingsGoalResponse:
    progress = goal.current_amount / goal.target_amount if goal.target_amount > 0 else 0.0
    return SavingsGoalResponse(
        id=goal.id,
        name=goal.name,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        sort_order=goal.sort_order,
        progress=round(progress, 4),
    )


@router.get("/{user_id}", response_model=list[SavingsGoalResponse])
async def list_savings_goals(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    if not await user_svc.get_by_id(user_id):
        raise HTTPException(status_code=404, detail="User not found")

    svc = SavingsGoalService(db)
    goals = await svc.list_for_user(user_id)
    return [_to_response(g) for g in goals]


@router.post("/{user_id}", response_model=SavingsGoalResponse, status_code=201)
async def create_savings_goal(
    user_id: uuid.UUID,
    body: CreateSavingsGoalRequest,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    if not await user_svc.get_by_id(user_id):
        raise HTTPException(status_code=404, detail="User not found")

    svc = SavingsGoalService(db)
    goal = await svc.create(
        user_id=user_id,
        name=body.name,
        target_amount=body.target_amount,
    )
    await db.commit()
    return _to_response(goal)


@router.put("/{user_id}/{goal_id}", response_model=SavingsGoalResponse)
async def update_savings_goal(
    user_id: uuid.UUID,
    goal_id: uuid.UUID,
    body: UpdateSavingsGoalRequest,
    db: AsyncSession = Depends(get_db),
):
    svc = SavingsGoalService(db)
    goal = await svc.get_by_id(goal_id)
    if not goal or goal.user_id != user_id:
        raise HTTPException(status_code=404, detail="Goal not found")

    goal = await svc.update(
        goal_id=goal_id,
        name=body.name,
        target_amount=body.target_amount,
        current_amount=body.current_amount,
    )
    await db.commit()
    return _to_response(goal)


@router.delete("/{user_id}/{goal_id}", status_code=204)
async def delete_savings_goal(
    user_id: uuid.UUID,
    goal_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    svc = SavingsGoalService(db)
    goal = await svc.get_by_id(goal_id)
    if not goal or goal.user_id != user_id:
        raise HTTPException(status_code=404, detail="Goal not found")

    await svc.delete(goal_id)
    await db.commit()
