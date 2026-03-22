"""Aggregates all data needed for the main dashboard."""

import uuid
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.categorization import ESSENTIAL_CATEGORIES
from app.services.goal_service import GoalService
from app.services.scoring import ScoringInput, ScoringOutput, calculate_tree_health
from app.services.transaction_service import TransactionService
from app.services.tree_service import TreeService


@dataclass
class CategoryBreakdown:
    category: str
    total: float
    count: int
    is_essential: bool


@dataclass
class ActionRecommendation:
    icon: str  # SF Symbol name
    title: str
    description: str
    priority: int  # 1 = highest


@dataclass
class DashboardData:
    # Tree
    tree_state: str
    health_score: int
    leaf_density: float
    stress_level: float
    explanation: str

    # Budget
    discretionary_spent: float
    discretionary_budget: float
    budget_remaining: float
    budget_percentage: float
    days_left_in_month: int

    # Spending breakdown
    top_categories: list[CategoryBreakdown] = field(default_factory=list)
    total_spending: float = 0.0
    total_income: float = 0.0

    # Actions
    actions: list[ActionRecommendation] = field(default_factory=list)

    # Scoring detail
    savings_progress: float = 0.0
    trend: str = "stable"


async def build_dashboard(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> DashboardData:
    """Build the full dashboard payload for a user."""

    today = date.today()
    month_start = today.replace(day=1)

    # Fetch data in parallel-ish (sequential but all from same session)
    txn_svc = TransactionService(db)
    goal_svc = GoalService(db)
    tree_svc = TreeService(db)

    transactions = await txn_svc.list_for_user(
        user_id, from_date=month_start, to_date=today
    )
    goal = await goal_svc.get_for_user(user_id)

    # Aggregate spending by category
    category_totals: dict[str, float] = {}
    category_counts: dict[str, int] = {}
    total_spending = 0.0
    total_income = 0.0
    discretionary_spent = 0.0

    for txn in transactions:
        amount = float(txn.amount)
        cat = txn.normalized_category or "other"

        if amount > 0:
            total_income += amount
            continue

        abs_amount = abs(amount)
        total_spending += abs_amount
        category_totals[cat] = category_totals.get(cat, 0.0) + abs_amount
        category_counts[cat] = category_counts.get(cat, 0) + 1

        if cat not in ESSENTIAL_CATEGORIES:
            discretionary_spent += abs_amount

    # Build sorted category breakdown
    top_categories = sorted(
        [
            CategoryBreakdown(
                category=cat,
                total=round(total, 2),
                count=category_counts[cat],
                is_essential=cat in ESSENTIAL_CATEGORIES,
            )
            for cat, total in category_totals.items()
        ],
        key=lambda c: c.total,
        reverse=True,
    )

    # Budget calculations
    budget = goal.monthly_discretionary_budget if goal else 0.0
    savings_target = goal.monthly_savings_target if goal else 0.0
    budget_remaining = max(0.0, budget - discretionary_spent) if budget > 0 else 0.0
    budget_pct = (discretionary_spent / budget * 100) if budget > 0 else 0.0

    # Days left
    import calendar

    _, days_in_month = calendar.monthrange(today.year, today.month)
    days_left = days_in_month - today.day

    # Savings progress
    savings_progress = 0.0
    if savings_target > 0 and total_income > 0:
        net = total_income - total_spending
        savings_progress = max(0.0, net / savings_target)

    # Determine trend from previous month
    prev_month_end = month_start
    prev_month_start = (month_start.replace(day=1) - __import__("datetime").timedelta(days=1)).replace(day=1)
    prev_transactions = await txn_svc.list_for_user(
        user_id, from_date=prev_month_start, to_date=prev_month_end
    )
    prev_discretionary = 0.0
    for txn in prev_transactions:
        amount = float(txn.amount)
        if amount < 0:
            cat = txn.normalized_category or "other"
            if cat not in ESSENTIAL_CATEGORIES:
                prev_discretionary += abs(amount)

    # Normalize to per-day to compare partial months
    days_elapsed = max(1, today.day)
    daily_current = discretionary_spent / days_elapsed
    prev_days = max(1, (prev_month_end - prev_month_start).days)
    daily_prev = prev_discretionary / prev_days if prev_discretionary > 0 else daily_current

    if daily_prev > 0:
        change = (daily_current - daily_prev) / daily_prev
        if change < -0.1:
            trend = "improving"
        elif change > 0.1:
            trend = "worsening"
        else:
            trend = "stable"
    else:
        trend = "stable"

    # Find dominant category
    top_cat = top_categories[0].category if top_categories else None
    top_cat_ratio = 0.0
    if top_cat and total_spending > 0:
        top_cat_ratio = (category_totals.get(top_cat, 0) / total_spending)

    # Calculate tree score
    scoring_result = calculate_tree_health(
        ScoringInput(
            discretionary_spent=Decimal(str(discretionary_spent)),
            discretionary_budget=Decimal(str(budget)),
            savings_progress=Decimal(str(savings_progress)),
            top_category=top_cat,
            top_category_ratio=top_cat_ratio,
            trend=trend,
        )
    )

    # Save today's snapshot
    await tree_svc.save_snapshot(
        user_id=user_id,
        snapshot_date=today,
        health_score=scoring_result.health_score,
        leaf_density=scoring_result.leaf_density,
        stress_level=scoring_result.stress_level,
        dominant_spending_category=top_cat,
        explanation=scoring_result.explanation,
    )

    # Generate action recommendations
    actions = _generate_actions(
        scoring_result=scoring_result,
        budget=budget,
        budget_pct=budget_pct,
        discretionary_spent=discretionary_spent,
        days_left=days_left,
        top_categories=top_categories,
        savings_progress=savings_progress,
        trend=trend,
        goal=goal,
    )

    return DashboardData(
        tree_state=scoring_result.tree_state,
        health_score=scoring_result.health_score,
        leaf_density=scoring_result.leaf_density,
        stress_level=scoring_result.stress_level,
        explanation=scoring_result.explanation,
        discretionary_spent=round(discretionary_spent, 2),
        discretionary_budget=round(budget, 2),
        budget_remaining=round(budget_remaining, 2),
        budget_percentage=round(budget_pct, 1),
        days_left_in_month=days_left,
        top_categories=top_categories[:5],
        total_spending=round(total_spending, 2),
        total_income=round(total_income, 2),
        actions=actions,
        savings_progress=round(savings_progress, 2),
        trend=trend,
    )


def _generate_actions(
    scoring_result: ScoringOutput,
    budget: float,
    budget_pct: float,
    discretionary_spent: float,
    days_left: int,
    top_categories: list[CategoryBreakdown],
    savings_progress: float,
    trend: str,
    goal,
) -> list[ActionRecommendation]:
    """Generate contextual action recommendations based on current state."""
    actions: list[ActionRecommendation] = []

    # No goal set
    if not goal or budget <= 0:
        actions.append(ActionRecommendation(
            icon="target",
            title="Set a spending budget",
            description="Set a monthly discretionary budget to track your spending and grow your tree.",
            priority=1,
        ))
        return actions

    # Over budget
    if budget_pct > 100:
        over_by = round(discretionary_spent - budget, 0)
        actions.append(ActionRecommendation(
            icon="exclamationmark.triangle",
            title="Over budget",
            description=f"You've exceeded your budget by {over_by:.0f} DKK. "
                        f"Try to avoid non-essential purchases for the rest of the month.",
            priority=1,
        ))

    # Approaching budget (>80%)
    elif budget_pct > 80:
        remaining = round(budget - discretionary_spent, 0)
        daily_allowance = round(remaining / max(1, days_left), 0)
        actions.append(ActionRecommendation(
            icon="chart.line.downtrend.xyaxis",
            title="Budget getting tight",
            description=f"You have {remaining:.0f} DKK left for {days_left} days — "
                        f"about {daily_allowance:.0f} DKK per day.",
            priority=2,
        ))

    # On track
    elif budget_pct < 60:
        actions.append(ActionRecommendation(
            icon="hand.thumbsup",
            title="Great pace",
            description=f"You've only used {budget_pct:.0f}% of your budget. "
                        f"Your tree is thriving!",
            priority=3,
        ))

    # Top discretionary category warning
    discretionary_cats = [
        c for c in top_categories if not c.is_essential
    ]
    if discretionary_cats:
        top = discretionary_cats[0]
        display_cat = top.category.replace("_", " ").title()
        if top.count >= 3 and top.total > budget * 0.3:
            actions.append(ActionRecommendation(
                icon="arrow.triangle.2.circlepath",
                title=f"Frequent {display_cat} spending",
                description=f"You've spent {top.total:.0f} DKK on {display_cat} "
                            f"across {top.count} transactions this month.",
                priority=2,
            ))

    # Savings progress
    if savings_progress < 0.5 and goal and goal.monthly_savings_target > 0:
        actions.append(ActionRecommendation(
            icon="banknote",
            title="Savings target at risk",
            description=f"You're at {savings_progress * 100:.0f}% of your savings goal. "
                        f"Consider reducing discretionary spending.",
            priority=2,
        ))
    elif savings_progress >= 1.0:
        actions.append(ActionRecommendation(
            icon="star.fill",
            title="Savings goal met!",
            description="You've reached your monthly savings target. Well done!",
            priority=3,
        ))

    # Worsening trend
    if trend == "worsening":
        actions.append(ActionRecommendation(
            icon="arrow.up.right",
            title="Spending is trending up",
            description="Your daily spending is higher than last month. "
                        "Small reductions now can make a big difference.",
            priority=2,
        ))

    # Sort by priority
    actions.sort(key=lambda a: a.priority)
    return actions[:4]
