import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.users import CreateUserRequest, LoginRequest, UserResponse
from app.db.session import get_db
from app.services.user_service import UserService, verify_password

router = APIRouter()


@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(
    body: CreateUserRequest,
    db: AsyncSession = Depends(get_db),
):
    svc = UserService(db)
    existing = await svc.get_by_email(body.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = await svc.create(email=body.email, name=body.name, password=body.password)
    await db.commit()
    return user


@router.post("/login", response_model=UserResponse)
async def login_user(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    svc = UserService(db)
    user = await svc.get_by_email(body.email)
    if not user or not user.password_hash or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return user


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    svc = UserService(db)
    user = await svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
