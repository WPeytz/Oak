"""Transaction normalization and categorization.

Maps raw merchant names and bank categories to Oak's normalized categories,
and classifies transactions as essential vs discretionary.
"""

from dataclasses import dataclass

# ---------------------------------------------------------------------------
# Category taxonomy
# ---------------------------------------------------------------------------

NORMALIZED_CATEGORIES = [
    "groceries",
    "eating_out",
    "shopping",
    "transport",
    "housing",
    "utilities",
    "subscriptions",
    "health",
    "education",
    "entertainment",
    "travel",
    "transfers",
    "income",
    "savings",
    "other",
]

ESSENTIAL_CATEGORIES = frozenset({
    "groceries",
    "housing",
    "utilities",
    "health",
    "education",
    "transport",
})

# ---------------------------------------------------------------------------
# Keyword → category mapping (lowercase)
# ---------------------------------------------------------------------------

_MERCHANT_KEYWORDS: dict[str, str] = {
    # Groceries
    "netto": "groceries",
    "føtex": "groceries",
    "rema": "groceries",
    "irma": "groceries",
    "lidl": "groceries",
    "aldi": "groceries",
    "coop": "groceries",
    "bilka": "groceries",
    "meny": "groceries",
    "spar": "groceries",
    "fakta": "groceries",
    "superbrugsen": "groceries",
    "7-eleven": "groceries",
    "dagligvare": "groceries",
    "grocery": "groceries",
    "supermarket": "groceries",
    # Eating out
    "restaurant": "eating_out",
    "café": "eating_out",
    "cafe": "eating_out",
    "starbucks": "eating_out",
    "mcdonald": "eating_out",
    "burger": "eating_out",
    "pizza": "eating_out",
    "sushi": "eating_out",
    "joe & the juice": "eating_out",
    "espresso": "eating_out",
    "takeaway": "eating_out",
    "wolt": "eating_out",
    "just eat": "eating_out",
    # Shopping
    "zalando": "shopping",
    "h&m": "shopping",
    "zara": "shopping",
    "apple store": "shopping",
    "amazon": "shopping",
    "ikea": "shopping",
    "elgiganten": "shopping",
    "power": "shopping",
    "magasin": "shopping",
    # Transport
    "dsb": "transport",
    "rejsekort": "transport",
    "uber": "transport",
    "taxi": "transport",
    "q8": "transport",
    "shell": "transport",
    "circle k": "transport",
    "ok benzin": "transport",
    "parking": "transport",
    # Subscriptions
    "netflix": "subscriptions",
    "spotify": "subscriptions",
    "hbo": "subscriptions",
    "disney": "subscriptions",
    "apple.com": "subscriptions",
    "google storage": "subscriptions",
    "fitness world": "subscriptions",
    "sats": "subscriptions",
    "gym": "subscriptions",
    # Housing
    "husleje": "housing",
    "bolig": "housing",
    "rent": "housing",
    "mortgage": "housing",
    "ejendom": "housing",
    # Utilities
    "ewii": "utilities",
    "ørsted": "utilities",
    "norlys": "utilities",
    "elnet": "utilities",
    "vand": "utilities",
    "varme": "utilities",
    "telia": "utilities",
    "telenor": "utilities",
    "3 mobil": "utilities",
    "yousef": "utilities",
    # Health
    "apotek": "health",
    "pharmacy": "health",
    "læge": "health",
    "doctor": "health",
    "tandlæge": "health",
    "dentist": "health",
    # Entertainment
    "cinema": "entertainment",
    "biograf": "entertainment",
    "tivoli": "entertainment",
    "koncert": "entertainment",
    "ticket": "entertainment",
    # Travel
    "hotel": "travel",
    "airbnb": "travel",
    "sas": "travel",
    "ryanair": "travel",
    "norwegian": "travel",
    "booking.com": "travel",
    # Income
    "løn": "income",
    "salary": "income",
    "stipendium": "income",
    "su ": "income",
    # Transfers
    "overførsel": "transfers",
    "transfer": "transfers",
    "mobilepay": "transfers",
}

_RAW_CATEGORY_MAP: dict[str, str] = {
    "groceries": "groceries",
    "eating out": "eating_out",
    "restaurants": "eating_out",
    "shopping": "shopping",
    "clothing": "shopping",
    "transport": "transport",
    "transportation": "transport",
    "subscriptions": "subscriptions",
    "entertainment": "entertainment",
    "health": "health",
    "education": "education",
    "travel": "travel",
    "income": "income",
    "housing": "housing",
    "utilities": "utilities",
    "transfers": "transfers",
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


@dataclass
class CategorizationResult:
    normalized_category: str
    is_essential: bool


def categorize_transaction(
    merchant: str | None,
    raw_description: str | None,
    raw_category: str | None,
    amount: float,
) -> CategorizationResult:
    """Determine the normalized category and essential flag for a transaction."""

    # Positive amounts are income
    if amount > 0:
        return CategorizationResult(
            normalized_category="income",
            is_essential=False,
        )

    category = _match_category(merchant, raw_description, raw_category)

    return CategorizationResult(
        normalized_category=category,
        is_essential=category in ESSENTIAL_CATEGORIES,
    )


def normalize_merchant(raw: str | None) -> str | None:
    """Clean up merchant name for display."""
    if not raw:
        return None
    # Strip common prefixes/suffixes
    cleaned = raw.strip()
    for prefix in ("Payment to ", "Betaling til ", "Køb "):
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):]
    return cleaned.strip() or None


def _match_category(
    merchant: str | None,
    description: str | None,
    raw_category: str | None,
) -> str:
    """Try to match a category from merchant, then description, then raw_category."""

    # 1. Try merchant keywords
    if merchant:
        lower = merchant.lower()
        for keyword, cat in _MERCHANT_KEYWORDS.items():
            if keyword in lower:
                return cat

    # 2. Try description keywords
    if description:
        lower = description.lower()
        for keyword, cat in _MERCHANT_KEYWORDS.items():
            if keyword in lower:
                return cat

    # 3. Try raw category from bank
    if raw_category:
        lower = raw_category.lower().strip()
        if lower in _RAW_CATEGORY_MAP:
            return _RAW_CATEGORY_MAP[lower]

    return "other"
