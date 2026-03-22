import uuid
from datetime import date

from sqlalchemy import Date, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class TreeState(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "tree_states"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_tree_state_user_date"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    health_score: Mapped[int] = mapped_column(Integer, nullable=False, default=50)
    leaf_density: Mapped[float] = mapped_column(Float, nullable=False, default=0.5)
    stress_level: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    dominant_spending_category: Mapped[str | None] = mapped_column(
        String(100), nullable=True
    )
    explanation: Mapped[str] = mapped_column(Text, nullable=False, default="")

    user: Mapped["User"] = relationship("User")


class SpendingGoal(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "spending_goals"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False
    )
    monthly_discretionary_budget: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )
    monthly_savings_target: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )

    user: Mapped["User"] = relationship("User", back_populates="spending_goal")
