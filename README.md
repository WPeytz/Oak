# Oak

Oak is an iPhone personal finance app that turns spending insights into concrete actions using a living tree metaphor.

Users connect their bank account via Open Banking (GoCardless). Oak retrieves transactions, identifies discretionary spending, and visualizes financial health as a tree that grows or decays based on behavior.

## Monorepo structure

```
ios/          SwiftUI iPhone app
backend/      FastAPI service (Python 3.12)
docs/         Shared documentation
```

## Quick start

### Backend

```bash
# Start PostgreSQL
docker compose up db -d

# Set up Python environment
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Run the API
uvicorn app.main:app --reload
```

The API will be at `http://localhost:8000`. Check health at `/health`.

### iOS

Open `ios/Oak/` in Xcode. The app targets iOS 17+.

### Full stack (Docker)

```bash
docker compose up
```

## Documentation

- [Architecture](docs/architecture.md)
- [Core Entities](docs/core_entities.md)
- [Money Tree Scoring Model](docs/money_tree_scoring_model.md)

## MVP features

1. User authentication
2. Bank connection via GoCardless
3. CSV import fallback
4. Transaction sync and categorization
5. Essential vs non-essential classification
6. Money Tree visualization
7. Insights dashboard
8. Action suggestions
9. Goal setting (budget + savings target)
