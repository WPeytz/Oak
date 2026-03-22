import uuid
from datetime import datetime

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class User(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)

    # Relationships
    bank_connections: Mapped[list["BankConnection"]] = relationship(
        "BankConnection", back_populates="user", lazy="selectin"
    )
    bank_accounts: Mapped[list["BankAccount"]] = relationship(
        "BankAccount", back_populates="user", lazy="selectin"
    )
    spending_goal: Mapped["SpendingGoal | None"] = relationship(
        "SpendingGoal", back_populates="user", uselist=False, lazy="selectin"
    )
