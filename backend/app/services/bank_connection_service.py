import uuid
from abc import ABC, abstractmethod
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bank_connection import BankConnection


class BankConnectionServiceBase(ABC):
    @abstractmethod
    async def get_by_id(
        self, connection_id: uuid.UUID
    ) -> BankConnection | None: ...

    @abstractmethod
    async def list_for_user(self, user_id: uuid.UUID) -> list[BankConnection]: ...

    @abstractmethod
    async def create(
        self,
        user_id: uuid.UUID,
        institution_id: str,
        requisition_id: str,
        provider: str = "tink",
    ) -> BankConnection: ...

    @abstractmethod
    async def update_status(
        self, connection_id: uuid.UUID, status: str
    ) -> BankConnection | None: ...

    @abstractmethod
    async def mark_synced(
        self, connection_id: uuid.UUID
    ) -> BankConnection | None: ...


class BankConnectionService(BankConnectionServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(
        self, connection_id: uuid.UUID
    ) -> BankConnection | None:
        return await self.db.get(BankConnection, connection_id)

    async def list_for_user(self, user_id: uuid.UUID) -> list[BankConnection]:
        result = await self.db.execute(
            select(BankConnection).where(BankConnection.user_id == user_id)
        )
        return list(result.scalars().all())

    async def create(
        self,
        user_id: uuid.UUID,
        institution_id: str,
        requisition_id: str,
        provider: str = "tink",
    ) -> BankConnection:
        conn = BankConnection(
            user_id=user_id,
            institution_id=institution_id,
            requisition_id=requisition_id,
            provider=provider,
        )
        self.db.add(conn)
        await self.db.flush()
        return conn

    async def update_status(
        self, connection_id: uuid.UUID, status: str
    ) -> BankConnection | None:
        conn = await self.get_by_id(connection_id)
        if conn:
            conn.status = status
            await self.db.flush()
        return conn

    async def mark_synced(
        self, connection_id: uuid.UUID
    ) -> BankConnection | None:
        conn = await self.get_by_id(connection_id)
        if conn:
            conn.last_synced_at = datetime.now()
            await self.db.flush()
        return conn
