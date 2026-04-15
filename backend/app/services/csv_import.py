"""Parse Danish bank CSV exports (Danske Bank, Nordea, Lån og Spar) and import as transactions."""

import csv
import hashlib
import io
import logging
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.categorization import categorize_transaction, normalize_merchant
from app.services.transaction_service import TransactionService

log = logging.getLogger(__name__)


# Danske Bank CSV category → Oak category mapping
_DK_CATEGORY_MAP: dict[str, str] = {
    "dagligvarer": "groceries",
    "supermarked": "groceries",
    "café/restaurant": "eating_out",
    "cafe/restaurant": "eating_out",
    "restaurant": "eating_out",
    "fornøjelser og fritid": "entertainment",
    "tøj og sko": "shopping",
    "bolig": "housing",
    "transport": "transport",
    "øvrige udgifter": "other",
    "telefon": "utilities",
    "forsikring": "utilities",
    "sundhed": "health",
    "uddannelse": "education",
}


def _parse_danish_date(s: str) -> date:
    """Parse 'dd.mm.yyyy' to date."""
    parts = s.strip().split(".")
    return date(int(parts[2]), int(parts[1]), int(parts[0]))


def _parse_danish_amount(s: str) -> Decimal:
    """Parse '-1.234,56' to Decimal."""
    cleaned = s.strip().replace('"', '').replace(".", "").replace(",", ".")
    return Decimal(cleaned)


def _generate_transaction_id(dato: str, tekst: str, belob: str, idx: int) -> str:
    """Generate a stable ID from the row content so re-imports are idempotent."""
    raw = f"{dato}|{tekst}|{belob}|{idx}"
    return f"csv-{hashlib.sha256(raw.encode()).hexdigest()[:16]}"


def parse_danske_bank_csv(content: str) -> list[dict]:
    """Parse a Danske Bank CSV string into a list of transaction dicts."""
    # Handle BOM and encoding issues
    content = content.lstrip("\ufeff")

    reader = csv.reader(io.StringIO(content), delimiter=";", quotechar='"')

    # Skip header
    header = next(reader, None)
    if not header:
        return []

    transactions = []
    for idx, row in enumerate(reader):
        if len(row) < 5:
            continue

        dato = row[0].strip().strip('"')
        kategori = row[1].strip().strip('"').strip()
        underkategori = row[2].strip().strip('"').strip()
        tekst = row[3].strip().strip('"')
        belob = row[4].strip().strip('"')

        if not dato or not belob:
            continue

        try:
            booked_at = _parse_danish_date(dato)
            amount = _parse_danish_amount(belob)
        except (ValueError, IndexError, ArithmeticError):
            continue

        # Use bank category or our own categorization
        raw_category = kategori if kategori.lower() not in ("ukategoriseret", "") else None
        raw_subcategory = underkategori if underkategori.lower() not in ("ukategoriseret", "") else None

        merchant = normalize_merchant(tekst)
        cat_result = categorize_transaction(
            merchant=merchant,
            raw_description=tekst,
            raw_category=raw_subcategory or raw_category,
            amount=float(amount),
        )

        transactions.append({
            "provider_transaction_id": _generate_transaction_id(dato, tekst, belob, idx),
            "booked_at": booked_at,
            "value_date": booked_at,
            "amount": amount,
            "currency": "DKK",
            "merchant": merchant,
            "raw_description": tekst,
            "raw_category": raw_category,
            "normalized_category": cat_result.normalized_category,
            "is_essential": cat_result.is_essential,
            "source": "csv",
        })

    return transactions


def _parse_nordea_date(s: str) -> date:
    """Parse Nordea date: accepts 'dd.mm.yyyy' or 'dd/mm/yyyy'."""
    raw = s.strip()
    sep = "." if "." in raw else "/"
    parts = raw.split(sep)
    return date(int(parts[2]), int(parts[1]), int(parts[0]))


def parse_nordea_csv(content: str) -> list[dict]:
    """Parse a Nordea CSV string into a list of transaction dicts.

    Nordea columns: Bogføringsdato;Beløb;Afsender;Modtager;Navn;Beskrivelse;Saldo;Valuta;Afstemt
    """
    content = content.lstrip("\ufeff")

    reader = csv.reader(io.StringIO(content), delimiter=";", quotechar='"')

    header = next(reader, None)
    if not header:
        return []

    transactions = []
    for idx, row in enumerate(reader):
        if len(row) < 7:
            continue

        dato = row[0].strip().strip('"')
        belob = row[1].strip().strip('"')
        navn = row[4].strip().strip('"')
        beskrivelse = row[5].strip().strip('"')
        valuta = row[7].strip().strip('"') if len(row) > 7 else "DKK"

        # Skip reserved (pending) transactions and empty rows
        if not dato or dato.lower() == "reserveret" or not belob:
            continue

        try:
            booked_at = _parse_nordea_date(dato)
            amount = _parse_danish_amount(belob)
        except (ValueError, IndexError, ArithmeticError):
            continue

        # Use beskrivelse as primary description, fall back to navn
        description = beskrivelse or navn
        merchant = normalize_merchant(description)
        cat_result = categorize_transaction(
            merchant=merchant,
            raw_description=description,
            raw_category=None,
            amount=float(amount),
        )

        transactions.append({
            "provider_transaction_id": _generate_transaction_id(dato, description, belob, idx),
            "booked_at": booked_at,
            "value_date": booked_at,
            "amount": amount,
            "currency": valuta or "DKK",
            "merchant": merchant,
            "raw_description": description,
            "raw_category": None,
            "normalized_category": cat_result.normalized_category,
            "is_essential": cat_result.is_essential,
            "source": "csv",
        })

    return transactions


def _parse_lsb_date(s: str) -> date:
    """Parse 'dd-mm-yyyy' to date."""
    parts = s.strip().split("-")
    return date(int(parts[2]), int(parts[1]), int(parts[0]))


def parse_lsb_csv(content: str) -> list[dict]:
    """Parse a Lån og Spar Bank CSV string into a list of transaction dicts.

    Columns: Dato;Tekst;Beløb;Saldo
    Date format: dd-mm-yyyy. Amount: Danish decimal (e.g. -450,50).
    Skips any preamble rows before the data starts.
    """
    content = content.lstrip("\ufeff")
    reader = csv.reader(io.StringIO(content), delimiter=";", quotechar='"')

    transactions = []
    for idx, row in enumerate(reader):
        if len(row) < 3:
            continue

        dato = row[0].strip().strip('"')
        tekst = row[1].strip().strip('"')
        belob = row[2].strip().strip('"')

        if not dato or not belob:
            continue

        try:
            booked_at = _parse_lsb_date(dato)
            amount = _parse_danish_amount(belob)
        except (ValueError, IndexError, ArithmeticError):
            # Header or preamble row — skip until we hit a valid data row
            continue

        merchant = normalize_merchant(tekst)
        cat_result = categorize_transaction(
            merchant=merchant,
            raw_description=tekst,
            raw_category=None,
            amount=float(amount),
        )

        transactions.append({
            "provider_transaction_id": _generate_transaction_id(dato, tekst, belob, idx),
            "booked_at": booked_at,
            "value_date": booked_at,
            "amount": amount,
            "currency": "DKK",
            "merchant": merchant,
            "raw_description": tekst,
            "raw_category": None,
            "normalized_category": cat_result.normalized_category,
            "is_essential": cat_result.is_essential,
            "source": "csv",
        })

    return transactions


def _detect_and_parse_csv(content: str) -> list[dict]:
    """Auto-detect CSV format (Danske Bank, Nordea, Lån og Spar) and parse accordingly."""
    head = content.lstrip("\ufeff")[:2000].lower()

    if "bogføringsdato" in head or "bogforingsdato" in head:
        log.info("csv_import: detected Nordea format")
        return parse_nordea_csv(content)

    # Lån og Spar: Dato;Tekst;Beløb;Saldo — look anywhere in the preamble
    if "tekst" in head and "saldo" in head and "kategori" not in head:
        log.info("csv_import: detected Lån og Spar format")
        return parse_lsb_csv(content)

    log.info("csv_import: defaulting to Danske Bank format")
    return parse_danske_bank_csv(content)


async def import_csv_transactions(
    db: AsyncSession,
    user_id: uuid.UUID,
    bank_account_id: uuid.UUID,
    csv_content: str,
) -> int:
    """Parse and import transactions from a Danish bank CSV export.

    Auto-detects the bank format (Danske Bank, Nordea).
    Returns the number of new transactions inserted.
    """
    records = _detect_and_parse_csv(csv_content)
    log.info("csv_import: parsed %d records for user %s", len(records), user_id)
    txn_svc = TransactionService(db)
    return await txn_svc.bulk_upsert(
        user_id=user_id,
        bank_account_id=bank_account_id,
        records=records,
    )
