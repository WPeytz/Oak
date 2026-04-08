from dataclasses import dataclass
from decimal import Decimal


@dataclass
class ScoringInput:
    total_income: float
    total_spending: float
    monthly_net_goal: float  # user's target net (income - spending)
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

    Primary metric: how close is your net (income - spending) to your goal.
    If you hit the goal, you get 100%. Below the goal scales linearly down.
    """
    net = scoring_input.total_income - scoring_input.total_spending
    goal = scoring_input.monthly_net_goal

    if goal != 0:
        # Net-goal based scoring
        # At or above goal → 100
        # At zero net → scales based on how far from goal
        # Negative net → can go below 0 but capped at 0
        if goal > 0:
            ratio = net / goal
        else:
            # Negative goal (user expects to spend more than earn)
            # If net >= goal, they're doing as well or better than expected
            ratio = 1.0 if net >= goal else net / goal

        # ratio >= 1.0 means goal met or exceeded → 100
        # ratio = 0.5 means halfway → 50
        # ratio <= 0 means no progress → 0
        score = max(0, min(100, int(ratio * 100)))
    else:
        # No net goal set — fall back to simple income/spending ratio
        if scoring_input.total_income > 0:
            ratio = scoring_input.total_spending / scoring_input.total_income
            score = max(0, min(100, int((1.0 - ratio) * 100)))
        elif scoring_input.total_spending > 0:
            score = 0
        else:
            score = 50  # no data

    # Small trend bonus/penalty (±5 points)
    if scoring_input.trend == "improving":
        score = min(100, score + 5)
    elif scoring_input.trend == "worsening":
        score = max(0, score - 5)

    score = max(0, min(100, score))

    tree_state = classify_tree_state(score)
    leaf_density = score / 100.0
    stress_level = max(0.0, (50 - score) / 50.0)

    explanation = _build_explanation(scoring_input, score, net, goal)

    return ScoringOutput(
        health_score=score,
        tree_state=tree_state,
        leaf_density=leaf_density,
        stress_level=stress_level,
        explanation=explanation,
    )


def _build_explanation(inp: ScoringInput, score: int, net: float, goal: float) -> str:
    parts: list[str] = []

    if goal != 0:
        if net >= goal:
            parts.append(f"You've hit your monthly net goal of {goal:,.0f} DKK!")
        else:
            progress = net / goal * 100 if goal != 0 else 0
            parts.append(
                f"Your net is {net:,.0f} DKK — {progress:.0f}% of your {goal:,.0f} DKK goal."
            )
    else:
        parts.append("Set a monthly net goal to get personalized tree health.")

    if inp.trend == "improving":
        parts.append("Your spending trend is improving.")
    elif inp.trend == "worsening":
        parts.append("Your spending has been increasing recently.")

    return " ".join(parts)
