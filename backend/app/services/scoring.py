from dataclasses import dataclass
from decimal import Decimal


@dataclass
class ScoringInput:
    discretionary_spent: Decimal
    discretionary_budget: Decimal
    savings_progress: Decimal  # 0.0 to 1.0+ (fraction of target achieved)
    top_category: str | None
    top_category_ratio: float  # how concentrated spending is in one category
    trend: str  # "improving" | "stable" | "worsening"


@dataclass
class ScoringOutput:
    health_score: int  # 0-100
    tree_state: str  # thriving | healthy | stressed | decaying
    leaf_density: float  # 0.0-1.0
    stress_level: float  # 0.0-1.0
    explanation: str


TREE_STATE_THRESHOLDS = [
    (80, "thriving"),
    (60, "healthy"),
    (40, "stressed"),
    (20, "decaying"),
    (0, "decaying"),
]


def classify_tree_state(score: int) -> str:
    for threshold, state in TREE_STATE_THRESHOLDS:
        if score >= threshold:
            return state
    return "decaying"


def calculate_tree_health(scoring_input: ScoringInput) -> ScoringOutput:
    """Calculate tree health score from recent financial behavior.

    See docs/money_tree_scoring_model.md for the scoring rules.
    """
    score = 50  # baseline

    # Budget adherence: -30 to +25
    if scoring_input.discretionary_budget > 0:
        ratio = float(
            scoring_input.discretionary_spent / scoring_input.discretionary_budget
        )
        if ratio <= 0.8:
            score += 25
        elif ratio <= 1.0:
            score += int(25 * (1.0 - ratio) / 0.2)
        elif ratio <= 1.5:
            score -= int(30 * (ratio - 1.0) / 0.5)
        else:
            score -= 30

    # Savings progress: -10 to +15
    progress = float(scoring_input.savings_progress)
    if progress >= 1.0:
        score += 15
    elif progress >= 0.5:
        score += int(15 * progress)
    else:
        score -= int(10 * (1.0 - progress * 2))

    # Category concentration penalty: 0 to -10
    if scoring_input.top_category_ratio > 0.5:
        score -= int(10 * (scoring_input.top_category_ratio - 0.5) / 0.5)

    # Trend bonus/penalty: -10 to +10
    if scoring_input.trend == "improving":
        score += 10
    elif scoring_input.trend == "worsening":
        score -= 10

    score = max(0, min(100, score))

    tree_state = classify_tree_state(score)
    leaf_density = score / 100.0
    stress_level = max(0.0, (50 - score) / 50.0)

    explanation = _build_explanation(scoring_input, score)

    return ScoringOutput(
        health_score=score,
        tree_state=tree_state,
        leaf_density=leaf_density,
        stress_level=stress_level,
        explanation=explanation,
    )


def _build_explanation(inp: ScoringInput, score: int) -> str:
    parts: list[str] = []

    if inp.discretionary_budget > 0:
        ratio = float(inp.discretionary_spent / inp.discretionary_budget)
        if ratio <= 1.0:
            parts.append(
                f"You're within your discretionary budget ({ratio:.0%} used)."
            )
        else:
            parts.append(
                f"You've exceeded your discretionary budget ({ratio:.0%} used)."
            )

    progress = float(inp.savings_progress)
    if progress >= 1.0:
        parts.append("You've met your savings target this month.")
    elif progress > 0:
        parts.append(f"You're {progress:.0%} of the way to your savings target.")

    if inp.trend == "improving":
        parts.append("Your spending trend is improving.")
    elif inp.trend == "worsening":
        parts.append("Your spending has been increasing recently.")

    if not parts:
        parts.append("Set a budget and savings target to get personalized insights.")

    return " ".join(parts)
