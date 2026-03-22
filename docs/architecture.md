# Architecture

## Monorepo layout

```
Oak/
├── ios/          # SwiftUI iPhone app
├── backend/      # FastAPI service
├── docs/         # Shared documentation
├── docker-compose.yml
└── CLAUDE.md
```

## iOS app (`ios/Oak/`)

- **App/** — entry point and app configuration
- **Features/** — one folder per screen/tab (Home, Tree, Insights, Settings)
- **Core/Models/** — shared data models
- **Core/Services/** — networking, persistence, business logic
- **Core/Navigation/** — tab bar and routing

## Backend (`backend/`)

- **app/main.py** — FastAPI entry point
- **app/config.py** — settings via pydantic-settings
- **app/api/routes/** — route modules grouped by domain
- **app/models/** — SQLAlchemy ORM models
- **app/services/** — business logic, one service per domain
- **app/db/** — database session and migrations

## Data flow

```
iPhone app  ──HTTP──>  FastAPI  ──SQL──>  PostgreSQL
                          │
                    Tink API
```

## Key decisions

- PostgreSQL as the single source of truth
- Tink Bank Account Data API for Open Banking
- Backend owns all scoring logic; iOS is a thin presentation layer
- Environment config via `.env` files (never committed)
