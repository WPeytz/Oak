# CLAUDE.md

## Project overview

Oak is a personal finance iOS app with a FastAPI backend. It visualizes financial health as a living tree that responds to spending behavior. This is a greenfield monorepo.

## Repository layout

- `ios/Oak/` — SwiftUI app (iOS 17+)
  - `App/` — entry point
  - `Features/{Home,Tree,Insights,Settings}/` — one folder per tab
  - `Core/Models/` — shared Codable structs
  - `Core/Services/` — API client, business logic
  - `Core/Navigation/` — tab bar and routing
- `backend/` — FastAPI (Python 3.12)
  - `app/main.py` — FastAPI entry point
  - `app/config.py` — pydantic-settings configuration
  - `app/api/routes/` — route moduleainAc
  - `app/models/` — SQLAlchemy ORM models (async, PostgreSQL)
  - `app/services/` — domain services with abstract base + concrete impl
  - `app/providers/tink/` — Tink Open Banking provider layer
  - `app/db/` — database session, base model, migrations
  - `tests/` — pytest tests
- `docs/` — shared documentation
- `web/` — landing page (oakapp.dk, deployed via Vercel)

## Development commands

```bash
# Backend
cd backend && uvicorn app.main:app --reload
cd backend && pytest

# Database
docker compose up db -d

# Full stack
docker compose up
```

## Key conventions

- Backend follows domain/service architecture: routes are thin, logic lives in `services/`
- Every service has an abstract base class (`*ServiceBase`) and a concrete implementation
- iOS follows feature-folder structure: each tab is a self-contained folder
- All scoring logic lives in the backend, not the iOS app
- Environment variables go in `.env` (never committed); copy from `.env.example`
- PostgreSQL is the single source of truth
- Tink API for Open Banking integration

## Tink provider layer

- `app/providers/tink/base.py` — abstract `BankingProviderBase` contract
- `app/providers/tink/sandbox.py` — in-memory sandbox (default, no credentials needed)
- `app/providers/tink/client.py` — live Tink API client (requires credentials)
- `app/providers/tink/factory.py` — returns sandbox or live based on `TINK_SANDBOX` env var
- Sandbox is the default (`TINK_SANDBOX=true`); set to `false` for production

## Domain entities

User, BankConnection, BankAccount, Transaction, SpendingGoal, TreeState — see `docs/core_entities.md`

## Scoring

The Money Tree health score (0-100) maps to tree visual states. See `docs/money_tree_scoring_model.md`

Scoring logic lives in `app/services/scoring.py` with `ScoringInput` / `ScoringOutput` dataclasses.
