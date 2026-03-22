import uuid
from abc import ABC, abstractmethod

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.savings_goal import SavingsGoal


class SavingsGoalServiceBase(ABC):
    @abstractmethod
    async def list_for_user(self, user_id: uuid.UUID) -> list[SavingsGoal]: ...

    @abstractmethod
    async def get_by_id(self, goal_id: uuid.UUID) -> SavingsGoal | None: ...

    @abstractmethod
    async def create(
        self, user_id: uuid.UUID, name: str, target_amount: float
    ) -> SavingsGoal: ...

    @abstractmethod
    async def update_amount(
        self, goal_id: uuid.UUID, current_amount: float
    ) -> SavingsGoal | None: ...

    @abstractmethod
    async def delete(self, goal_id: uuid.UUID) -> bool: ...


class SavingsGoalService(SavingsGoalServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_for_user(self, user_id: uuid.UUID) -> list[SavingsGoal]:
        result = await self.db.execute(
            select(SavingsGoal)
            .where(SavingsGoal.user_id == user_id)
            .order_by(SavingsGoal.sort_order)
        )
        return list(result.scalars().all())

    async def get_by_id(self, goal_id: uuid.UUID) -> SavingsGoal | None:
        return await self.db.get(SavingsGoal, goal_id)

    async def create(
        self, user_id: uuid.UUID, name: str, target_amount: float
    ) -> SavingsGoal:
        # Get next sort order
        existing = await self.list_for_user(user_id)
        sort_order = len(existing)

        goal = SavingsGoal(
            user_id=user_id,
            name=name,
            target_amount=target_amount,
            current_amount=0.0,
            sort_order=sort_order,
        )
        self.db.add(goal)
        await self.db.flush()
        return goal

    async def update_amount(
        self, goal_id: uuid.UUID, current_amount: float
    ) -> SavingsGoal | None:
        goal = await self.get_by_id(goal_id)
        if goal:
            goal.current_amount = current_amount
            await self.db.flush()
        return goal

    async def update(
        self,
        goal_id: uuid.UUID,
        name: str | None = None,
        target_amount: float | None = None,
        current_amount: float | None = None,
    ) -> SavingsGoal | None:
        goal = await self.get_by_id(goal_id)
        if not goal:
            return None
        if name is not None:
            goal.name = name
        if target_amount is not None:
            goal.target_amount = target_amount
        if current_amount is not None:
            goal.current_amount = current_amount
        await self.db.flush()
        return goal

    async def delete(self, goal_id: uuid.UUID) -> bool:
        goal = await self.get_by_id(goal_id)
        if not goal:
            return False
        await self.db.delete(goal)
        await self.db.flush()
        return True
