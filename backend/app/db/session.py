from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings


def _ensure_async_url(url: str) -> str:
    """Convert postgresql:// to postgresql+asyncpg:// for async SQLAlchemy."""
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


engine = create_async_engine(_ensure_async_url(settings.database_url), echo=settings.debug)

async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session
