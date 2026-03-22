import uuid
from datetime import datetime

from pydantic import BaseModel


class InstitutionResponse(BaseModel):
    id: str
    name: str
    logo_url: str
    countries: list[str]


class CreateConnectionRequest(BaseModel):
    institution_id: str


class ConnectionResponse(BaseModel):
    id: uuid.UUID
    institution_id: str
    requisition_id: str
    status: str
    authorization_url: str | None = None
    created_at: datetime
    last_synced_at: datetime | None = None

    model_config = {"from_attributes": True}


class ConnectionStatusResponse(BaseModel):
    id: uuid.UUID
    status: str  # pending | linked | expired | revoked
    accounts_synced: int = 0
