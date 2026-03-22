import uuid
from abc import ABC, abstractmethod

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bank_account import BankAccount


class BankAccountServiceBase(ABC):
    @abstractmethod
    async def get_by_id(self, account_id: uuid.UUID) -> BankAccount | None: ...

    @abstractmethod
    async def list_for_user(self, user_id: uuid.UUID) -> list[BankAccount]: ...

    @abstractmethod
    async def list_for_connection(
        self, connection_id: uuid.UUID
    ) -> list[BankAccount]: ...

    @abstractmethod
    async def upsert_from_provider(
        self,
        user_id: uuid.UUID,
        connection_id: uuid.UUID,
        provider_account_id: str,
        name: str,
        iban_masked: str | None,
        currency: str,
    ) -> BankAccount: ...


class BankAccountService(BankAccountServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, account_id: uuid.UUID) -> BankAccount | None:
        return await self.db.get(BankAccount, account_id)

    async def list_for_user(self, user_id: uuid.UUID) -> list[BankAccount]:
        result = await self.db.execute(
            select(BankAccount).where(BankAccount.user_id == user_id)
        )
        return list(result.scalars().all())

    async def list_for_connection(
        self, connection_id: uuid.UUID
    ) -> list[BankAccount]:
        result = await self.db.execute(
            select(BankAccount).where(BankAccount.connection_id == connection_id)
        )
        return list(result.scalars().all())

    async def upsert_from_provider(
        self,
        user_id: uuid.UUID,
        connection_id: uuid.UUID,
        provider_account_id: str,
        name: str,
        iban_masked: str | None,
        currency: str,
    ) -> BankAccount:
        result = await self.db.execute(
            select(BankAccount).where(
                BankAccount.provider_account_id == provider_account_id
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.name = name
            existing.iban_masked = iban_masked
            existing.currency = currency
            await self.db.flush()
            return existing

        account = BankAccount(
            user_id=user_id,
            connection_id=connection_id,
            provider_account_id=provider_account_id,
            name=name,
            iban_masked=iban_masked,
            currency=currency,
        )
        self.db.add(account)
        await self.db.flush()
        return account
