from decimal import Decimal

from app.services.scoring import ScoringInput, ScoringOutput, calculate_tree_health


def _make_input(**overrides) -> ScoringInput:
    defaults = {
        "discretionary_spent": Decimal("500"),
        "discretionary_budget": Decimal("1000"),
        "savings_progress": Decimal("0.5"),
        "top_category": "Groceries",
        "top_category_ratio": 0.3,
        "trend": "stable",
    }
    defaults.update(overrides)
    return ScoringInput(**defaults)


def test_baseline_within_budget():
    result = calculate_tree_health(_make_input())
    assert 60 <= result.health_score <= 100
    assert result.tree_state in ("thriving", "healthy")


def test_over_budget_reduces_score():
    under = calculate_tree_health(
        _make_input(discretionary_spent=Decimal("800"))
    )
    over = calculate_tree_health(
        _make_input(discretionary_spent=Decimal("1500"))
    )
    assert over.health_score < under.health_score


def test_savings_met_boosts_score():
    low = calculate_tree_health(_make_input(savings_progress=Decimal("0.2")))
    high = calculate_tree_health(_make_input(savings_progress=Decimal("1.0")))
    assert high.health_score > low.health_score


def test_worsening_trend_penalty():
    stable = calculate_tree_health(_make_input(trend="stable"))
    worsening = calculate_tree_health(_make_input(trend="worsening"))
    assert worsening.health_score < stable.health_score


def test_improving_trend_bonus():
    stable = calculate_tree_health(_make_input(trend="stable"))
    improving = calculate_tree_health(_make_input(trend="improving"))
    assert improving.health_score > stable.health_score


def test_score_clamped_0_100():
    worst = calculate_tree_health(
        _make_input(
            discretionary_spent=Decimal("5000"),
            savings_progress=Decimal("0"),
            top_category_ratio=0.9,
            trend="worsening",
        )
    )
    assert worst.health_score >= 0
    best = calculate_tree_health(
        _make_input(
            discretionary_spent=Decimal("100"),
            savings_progress=Decimal("2.0"),
            top_category_ratio=0.1,
            trend="improving",
        )
    )
    assert best.health_score <= 100


def test_tree_state_mapping():
    thriving = calculate_tree_health(
        _make_input(
            discretionary_spent=Decimal("200"),
            savings_progress=Decimal("1.5"),
            trend="improving",
        )
    )
    assert thriving.tree_state == "thriving"

    decaying = calculate_tree_health(
        _make_input(
            discretionary_spent=Decimal("3000"),
            savings_progress=Decimal("0"),
            top_category_ratio=0.9,
            trend="worsening",
        )
    )
    assert decaying.tree_state in ("stressed", "decaying")


def test_explanation_contains_content():
    result = calculate_tree_health(_make_input())
    assert len(result.explanation) > 0
    assert "budget" in result.explanation.lower()
