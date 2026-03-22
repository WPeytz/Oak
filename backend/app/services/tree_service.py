import uuid
from abc import ABC, abstractmethod
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tree import TreeState


class TreeServiceBase(ABC):
    @abstractmethod
    async def get_current(self, user_id: uuid.UUID) -> TreeState | None: ...

    @abstractmethod
    async def get_history(
        self,
        user_id: uuid.UUID,
        from_date: date | None = None,
        to_date: date | None = None,
    ) -> list[TreeState]: ...

    @abstractmethod
    async def save_snapshot(
        self,
        user_id: uuid.UUID,
        snapshot_date: date,
        health_score: int,
        leaf_density: float,
        stress_level: float,
        dominant_spending_category: str | None,
        explanation: str,
    ) -> TreeState: ...


class TreeService(TreeServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_current(self, user_id: uuid.UUID) -> TreeState | None:
        result = await self.db.execute(
            select(TreeState)
            .where(TreeState.user_id == user_id)
            .order_by(TreeState.date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_history(
        self,
        user_id: uuid.UUID,
        from_date: date | None = None,
        to_date: date | None = None,
    ) -> list[TreeState]:
        stmt = select(TreeState).where(TreeState.user_id == user_id)
        if from_date:
            stmt = stmt.where(TreeState.date >= from_date)
        if to_date:
            stmt = stmt.where(TreeState.date <= to_date)
        stmt = stmt.order_by(TreeState.date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def save_snapshot(
        self,
        user_id: uuid.UUID,
        snapshot_date: date,
        health_score: int,
        leaf_density: float,
        stress_level: float,
        dominant_spending_category: str | None,
        explanation: str,
    ) -> TreeState:
        # Upsert: one snapshot per user per day
        result = await self.db.execute(
            select(TreeState).where(
                TreeState.user_id == user_id,
                TreeState.date == snapshot_date,
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.health_score = health_score
            existing.leaf_density = leaf_density
            existing.stress_level = stress_level
            existing.dominant_spending_category = dominant_spending_category
            existing.explanation = explanation
            await self.db.flush()
            return existing

        state = TreeState(
            user_id=user_id,
            date=snapshot_date,
            health_score=health_score,
            leaf_density=leaf_density,
            stress_level=stress_level,
            dominant_spending_category=dominant_spending_category,
            explanation=explanation,
        )
        self.db.add(state)
        await self.db.flush()
        return state
