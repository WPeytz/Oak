import uuid
from abc import ABC, abstractmethod

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tree import SpendingGoal


class GoalServiceBase(ABC):
    @abstractmethod
    async def get_for_user(self, user_id: uuid.UUID) -> SpendingGoal | None: ...

    @abstractmethod
    async def upsert(
        self,
        user_id: uuid.UUID,
        monthly_discretionary_budget: float,
        monthly_savings_target: float,
    ) -> SpendingGoal: ...


class GoalService(GoalServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_for_user(self, user_id: uuid.UUID) -> SpendingGoal | None:
        result = await self.db.execute(
            select(SpendingGoal).where(SpendingGoal.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def upsert(
        self,
        user_id: uuid.UUID,
        monthly_discretionary_budget: float,
        monthly_savings_target: float,
    ) -> SpendingGoal:
        existing = await self.get_for_user(user_id)
        if existing:
            existing.monthly_discretionary_budget = monthly_discretionary_budget
            existing.monthly_savings_target = monthly_savings_target
            await self.db.flush()
            return existing

        goal = SpendingGoal(
            user_id=user_id,
            monthly_discretionary_budget=monthly_discretionary_budget,
            monthly_savings_target=monthly_savings_target,
        )
        self.db.add(goal)
        await self.db.flush()
        return goal
