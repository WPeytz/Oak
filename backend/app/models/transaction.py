import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import Boolean, Date, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class Transaction(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint("user_id", "provider_transaction_id", name="uq_transaction_user_provider"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    bank_account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("bank_accounts.id"), nullable=False
    )
    provider_transaction_id: Mapped[str | None] = mapped_column(
        String(200), nullable=True
    )

    booked_at: Mapped[date] = mapped_column(Date, nullable=False)
    value_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="EUR")

    merchant: Mapped[str | None] = mapped_column(String(300), nullable=True)
    raw_description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    raw_category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    normalized_category: Mapped[str | None] = mapped_column(
        String(100), nullable=True
    )
    is_essential: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    source: Mapped[str] = mapped_column(
        String(20), nullable=False, default="tink"
    )  # tink | csv

    # Relationships
    bank_account: Mapped["BankAccount"] = relationship(
        "BankAccount", back_populates="transactions"
    )
