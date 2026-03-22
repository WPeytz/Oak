import uuid

from sqlalchemy import ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class BankAccount(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "bank_accounts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    connection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("bank_connections.id"), nullable=False
    )
    provider_account_id: Mapped[str] = mapped_column(
        String(200), unique=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    iban_masked: Mapped[str | None] = mapped_column(String(50), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="EUR")

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="bank_accounts")
    connection: Mapped["BankConnection"] = relationship(
        "BankConnection", back_populates="accounts"
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction", back_populates="bank_account", lazy="selectin"
    )
