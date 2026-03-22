from app.services.categorization import (
    categorize_transaction,
    normalize_merchant,
)


def test_income_positive_amount():
    result = categorize_transaction(
        merchant="Employer", raw_description=None, raw_category=None, amount=12500.0
    )
    assert result.normalized_category == "income"
    assert result.is_essential is False


def test_groceries_by_merchant():
    result = categorize_transaction(
        merchant="Netto", raw_description=None, raw_category=None, amount=-249.0
    )
    assert result.normalized_category == "groceries"
    assert result.is_essential is True


def test_eating_out_by_merchant():
    result = categorize_transaction(
        merchant="Starbucks", raw_description=None, raw_category=None, amount=-89.0
    )
    assert result.normalized_category == "eating_out"
    assert result.is_essential is False


def test_shopping_by_merchant():
    result = categorize_transaction(
        merchant="Zalando", raw_description=None, raw_category=None, amount=-1299.0
    )
    assert result.normalized_category == "shopping"
    assert result.is_essential is False


def test_subscriptions_by_merchant():
    result = categorize_transaction(
        merchant="Netflix", raw_description=None, raw_category=None, amount=-199.0
    )
    assert result.normalized_category == "subscriptions"
    assert result.is_essential is False


def test_fallback_to_description():
    result = categorize_transaction(
        merchant=None,
        raw_description="Payment to Føtex store",
        raw_category=None,
        amount=-320.0,
    )
    assert result.normalized_category == "groceries"


def test_fallback_to_raw_category():
    result = categorize_transaction(
        merchant="Unknown Store",
        raw_description=None,
        raw_category="Shopping",
        amount=-500.0,
    )
    assert result.normalized_category == "shopping"


def test_unknown_falls_to_other():
    result = categorize_transaction(
        merchant="XYZABC Corp",
        raw_description="XYZABC payment",
        raw_category="MISC",
        amount=-100.0,
    )
    assert result.normalized_category == "other"
    assert result.is_essential is False


def test_essential_categories():
    for merchant, expected_essential in [
        ("Netto", True),      # groceries
        ("DSB", True),        # transport
        ("Apotek", True),     # health
        ("Zalando", False),   # shopping
        ("Netflix", False),   # subscriptions
        ("Restaurant", False),  # eating_out
    ]:
        result = categorize_transaction(
            merchant=merchant, raw_description=None, raw_category=None, amount=-100.0
        )
        assert result.is_essential is expected_essential, (
            f"{merchant}: expected essential={expected_essential}, "
            f"got {result.is_essential} (cat={result.normalized_category})"
        )


def test_normalize_merchant_strips_prefix():
    assert normalize_merchant("Payment to Netto") == "Netto"
    assert normalize_merchant("Betaling til Føtex") == "Føtex"


def test_normalize_merchant_none():
    assert normalize_merchant(None) is None
    assert normalize_merchant("") is None


def test_case_insensitive_matching():
    result = categorize_transaction(
        merchant="NETTO AMAGER", raw_description=None, raw_category=None, amount=-200.0
    )
    assert result.normalized_category == "groceries"
