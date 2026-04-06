import uuid

from pydantic import BaseModel, Field


class UpsertGoalRequest(BaseModel):
    monthly_discretionary_budget: float = Field(ge=0, default=0.0)
    monthly_savings_target: float = Field(ge=0, default=0.0)
    monthly_net_goal: float = Field(default=0.0)


class GoalResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    monthly_discretionary_budget: float
    monthly_savings_target: float
    monthly_net_goal: float

    model_config = {"from_attributes": True}
