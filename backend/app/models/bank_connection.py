import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class BankConnection(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "bank_connections"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    provider: Mapped[str] = mapped_column(
        String(50), nullable=False, default="gocardless"
    )
    institution_id: Mapped[str] = mapped_column(String(100), nullable=False)
    requisition_id: Mapped[str] = mapped_column(
        String(200), unique=True, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending"
    )  # pending | linked | expired | revoked
    last_synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="bank_connections")
    accounts: Mapped[list["BankAccount"]] = relationship(
        "BankAccount", back_populates="connection", lazy="selectin"
    )
