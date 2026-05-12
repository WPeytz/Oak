# Oak

Oak is an iPhone personal finance app that turns spending insights into concrete actions using a living tree metaphor.

Users connect their bank account via Open Banking (Tink). Oak retrieves transactions, identifies discretionary spending, and visualizes financial health as a tree that grows or decays based on behavior.

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

The app targets iOS 17+ and requires Xcode 16 or newer.

**From Xcode (recommended):**

1. Open `ios/Oak.xcodeproj`.
2. Select the `Oak` scheme and an iPhone simulator (e.g. iPhone 17).
3. Press ⌘R to build and run.

**From the command line:**

```bash
# Build for the iPhone 17 simulator
xcodebuild -project ios/Oak.xcodeproj -scheme Oak \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Install and launch on a booted simulator
xcrun simctl boot "iPhone 17"
open -a Simulator
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/Oak-*/Build/Products/Debug-iphonesimulator/Oak.app
xcrun simctl launch booted dk.oakapp.money
```

The app expects the backend on `http://localhost:8000` — start it first (see above).

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
2. Bank connection via Tink
3. CSV import fallback
4. Transaction sync and categorization
5. Essential vs non-essential classification
6. Money Tree visualization
7. Insights dashboard
8. Action suggestions
9. Goal setting (budget + savings target)
