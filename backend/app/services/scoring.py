from dataclasses import dataclass
from decimal import Decimal


@dataclass
class ScoringInput:
    total_income: float
    total_spending: float
    monthly_net_goal: float
    discretionary_spent: Decimal
    discretionary_budget: Decimal
    savings_progress: Decimal
    top_category: str | None
    top_category_ratio: float
    trend: str


@dataclass
class ScoringOutput:
    health_score: int
    tree_state: str
    leaf_density: float
    stress_level: float
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
    net = scoring_input.total_income - scoring_input.total_spending
    goal = scoring_input.monthly_net_goal

    if goal != 0:
        if goal > 0:
            ratio = net / goal
        else:
            ratio = 1.0 if net >= goal else net / goal

        score = max(0, min(100, int(ratio * 100)))
    else:
        if scoring_input.total_income > 0:
            ratio = scoring_input.total_spending / scoring_input.total_income
            score = max(0, min(100, int((1.0 - ratio) * 100)))
        elif scoring_input.total_spending > 0:
            score = 0
        else:
            score = 50

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
