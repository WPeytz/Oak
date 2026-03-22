from pydantic import BaseModel


class CategoryBreakdownResponse(BaseModel):
    category: str
    total: float
    count: int
    is_essential: bool


class ActionResponse(BaseModel):
    icon: str
    title: str
    description: str
    priority: int


class DashboardResponse(BaseModel):
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

    # Spending
    top_categories: list[CategoryBreakdownResponse]
    total_spending: float
    total_income: float

    # Actions
    actions: list[ActionResponse]

    # Meta
    savings_progress: float
    trend: str
