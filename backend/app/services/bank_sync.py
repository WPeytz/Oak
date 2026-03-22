"""Orchestrates bank data sync using the banking provider and domain services."""

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.providers.gocardless import get_banking_provider
from app.services.bank_account_service import BankAccountService
from app.services.bank_connection_service import BankConnectionService
from app.services.categorization import categorize_transaction, normalize_merchant
from app.services.transaction_service import TransactionService


async def sync_accounts_for_connection(
    db: AsyncSession,
    user_id: uuid.UUID,
    connection_id: uuid.UUID,
    requisition_id: str,
) -> int:
    """Fetch accounts from the provider and upsert them locally.

    Returns the number of accounts synced.
    """
    provider = get_banking_provider()
    account_svc = BankAccountService(db)

    requisition = await provider.get_requisition(requisition_id)
    count = 0
    for provider_account_id in requisition.accounts:
        details = await provider.get_account_details(provider_account_id)
        await account_svc.upsert_from_provider(
            user_id=user_id,
            connection_id=connection_id,
            provider_account_id=details.id,
            name=details.name,
            iban_masked=_mask_iban(details.iban),
            currency=details.currency,
        )
        count += 1
    return count


async def sync_transactions_for_user(
    db: AsyncSession,
    user_id: uuid.UUID,
    date_from: date | None = None,
    date_to: date | None = None,
) -> int:
    """Sync transactions for all of a user's connected accounts.

    Returns total number of new transactions inserted.
    """
    account_svc = BankAccountService(db)
    accounts = await account_svc.list_for_user(user_id)

    total = 0
    for account in accounts:
        count = await sync_transactions_for_account(
            db=db,
            user_id=user_id,
            bank_account_id=account.id,
            provider_account_id=account.provider_account_id,
            date_from=date_from,
            date_to=date_to,
        )
        total += count
    return total


async def sync_transactions_for_account(
    db: AsyncSession,
    user_id: uuid.UUID,
    bank_account_id: uuid.UUID,
    provider_account_id: str,
    date_from: date | None = None,
    date_to: date | None = None,
) -> int:
    """Fetch transactions from the provider, categorize, and upsert.

    Returns the number of new transactions inserted.
    """
    provider = get_banking_provider()
    txn_svc = TransactionService(db)

    provider_txns = await provider.list_transactions(
        account_id=provider_account_id,
        date_from=date_from,
        date_to=date_to,
    )

    records = []
    for pt in provider_txns:
        amount = Decimal(pt.amount)
        merchant = normalize_merchant(pt.merchant)
        cat_result = categorize_transaction(
            merchant=merchant,
            raw_description=pt.description,
            raw_category=pt.category,
            amount=float(amount),
        )

        records.append(
            {
                "provider_transaction_id": pt.transaction_id,
                "booked_at": pt.booked_at,
                "value_date": pt.value_date,
                "amount": amount,
                "currency": pt.currency,
                "merchant": merchant,
                "raw_description": pt.description,
                "raw_category": pt.category,
                "normalized_category": cat_result.normalized_category,
                "is_essential": cat_result.is_essential,
            }
        )

    return await txn_svc.bulk_upsert(
        user_id=user_id,
        bank_account_id=bank_account_id,
        records=records,
    )


def _mask_iban(iban: str | None) -> str | None:
    if not iban:
        return None
    clean = iban.replace(" ", "")
    if len(clean) <= 6:
        return clean
    return clean[:4] + " **** " + clean[-4:]
