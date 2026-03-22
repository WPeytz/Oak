import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.dashboard import (
    ActionResponse,
    CategoryBreakdownResponse,
    DashboardResponse,
)
from app.db.session import get_db
from app.services.dashboard_service import build_dashboard
from app.services.user_service import UserService

router = APIRouter()


@router.get("/{user_id}", response_model=DashboardResponse)
async def get_dashboard(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    data = await build_dashboard(db, user_id)
    await db.commit()  # persist tree snapshot

    return DashboardResponse(
        tree_state=data.tree_state,
        health_score=data.health_score,
        leaf_density=data.leaf_density,
        stress_level=data.stress_level,
        explanation=data.explanation,
        discretionary_spent=data.discretionary_spent,
        discretionary_budget=data.discretionary_budget,
        budget_remaining=data.budget_remaining,
        budget_percentage=data.budget_percentage,
        days_left_in_month=data.days_left_in_month,
        top_categories=[
            CategoryBreakdownResponse(
                category=c.category,
                total=c.total,
                count=c.count,
                is_essential=c.is_essential,
            )
            for c in data.top_categories
        ],
        total_spending=data.total_spending,
        total_income=data.total_income,
        actions=[
            ActionResponse(
                icon=a.icon,
                title=a.title,
                description=a.description,
                priority=a.priority,
            )
            for a in data.actions
        ],
        savings_progress=data.savings_progress,
        trend=data.trend,
    )
