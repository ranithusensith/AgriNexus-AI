# AgriNexus AI

A smart agriculture platform for Sri Lankan farmers, built as a university group project.

| | |
|---|---|
| **Frontend** | Flutter (Dart) — **Android** (iOS is out of scope) |
| **Backend** | Python, FastAPI |
| **Database** | PostgreSQL |
| **AI/ML** | Python (TensorFlow / PyTorch / TFLite, pluggable) |
| **Languages** | English, Sinhala (සිංහල), Tamil (தமிழ்) |

---

## Modules and ownership

| # | Module | Owner | Status |
|---|---|---|---|
| 1 | Farmer + AI Agriculture | Member 1 (`member1/farmer-ai`) | Implemented — see below |
| 2 | Marketplace | Member 2 | Integrated: routers mounted, tables migrated, Flutter screens wired (needs `flutter analyze`) |
| 3 | Communication + Community | Member 3 | Implemented: chat, community feed, issue reports (backend + Flutter), see below |

Each member works on their own branch and only touches their own module.

---

## Repository structure

```
AgriNexus-AI/
├── README.md               ← this file
├── backend/                ← FastAPI app (see backend/README.md)
│   ├── app/
│   │   ├── main.py         ← app entry, mounts routers
│   │   ├── config.py       ← env-based settings
│   │   ├── database.py     ← SQLAlchemy engine/session
│   │   ├── core/           ← JWT, password hashing, auth dependencies
│   │   ├── models/         ← SQLAlchemy tables
│   │   ├── schemas/        ← Pydantic request/response models
│   │   ├── routers/        ← API endpoints
│   │   ├── services/       ← AI model abstractions, recommendation, weather
│   │   └── tests/          ← pytest suite
│   ├── alembic/            ← migration scaffolding
│   ├── requirements.txt
│   └── .env.example
└── frontend/               ← Flutter app (see frontend/README.md)
    ├── pubspec.yaml
    ├── l10n.yaml
    └── lib/
        ├── main.dart
        ├── shared/         ← API client, models, services, state, widgets, l10n
        └── features/       ← one folder per feature area
```

---

## Module 1 — Farmer + AI Agriculture

### Features

- **Authentication** — register, login, logout, refresh tokens, roles, bcrypt password hashing, JWT
- **Farmer profile** — name, phone, email, district, location, profile image, farmer info
- **Farm management** — create / edit / delete farms (size, soil info, water availability)
- **Crop management** — add / edit / delete crops, status tracking, automatic crop history log
- **AI plant disease detection** — image upload → disease, confidence, symptoms, recommended actions
- **Pest identification** — same architecture as disease detection
- **AI crop recommendation** — soil/climate inputs → ranked crops with reasons and warnings
- **Weather** — location-based weather plus rule-based agricultural advice
- **Farmer feedback** — record field observations (waterlogging, drought, salinity, pest/disease outbreak, etc.)

### Backend API ownership

Module 1 owns these route prefixes only:

| Prefix | Purpose |
|---|---|
| `/users` | Register, login, refresh, logout, `/me`, profile, profile image |
| `/farms` | Farm CRUD |
| `/crops` | Crop CRUD + history |
| `/disease-detection` | Upload image, get result, `/history` |
| `/pest-detection` | Upload image, get result, `/history` |
| `/crop-recommendations` | Soil/climate inputs → ranked suggestions |
| `/weather` | Current weather + advisories (`GET /weather?location=...`) |
| `/farmer-feedback` | Create / list observations |

Interactive docs are available at `http://localhost:8000/docs` when the backend is running.

### Flutter screens

Login, Register, Farmer Dashboard, Farmer Profile, My Farms, Add/Edit Farm, Farm Details, My Crops, Add Crop, Crop Details, AI Plant Doctor, Disease Result, Pest Identification, Crop Recommendation, Weather, Farmer Feedback.

---

## Marketplace API (Module 2)

Prefix `/api`: `/categories`, `/listings`, `/products`, `/orders`, `/reviews`, `/suppliers`, `/buyers`. Roles: `farmer`, `supplier` (can sell), `buyer`, `admin` (manages categories; cannot be self-registered, create it directly in the DB). Ownership rules live in `backend/app/core/permissions.py`.

---

## Module 3 — Communication + Community

### Features

- **Chat**: 1-to-1 conversations between any two users, optionally linked to a Marketplace listing. Shows the last message and unread count. Delivery is by **polling** (no websockets): the app re-fetches every `CHAT_POLL_INTERVAL_SECONDS` (default 5 s) while a chat screen is open. Only the two participants can read a conversation; admins can't either.
- **Community**: posts (title, body, optional image, category), comments, likes; search, category/author filter, pagination. Authors edit their own content; authors or admins delete it.
- **Issue reports**: any user can report a post, comment, user or listing. Admins list and filter reports and move them through `open → reviewed → resolved | dismissed`.

### API

All endpoints need a bearer token. Malformed ids return 422, unknown ids 404, ownership failures 403.

| Method & path | Purpose |
|---|---|
| `POST /api/chat/conversations` | Get or create the conversation with `participant_id` (+ optional `listing_id`). 201 if new, 200 if existing |
| `GET /api/chat/conversations` | My conversations, most recent first, with `last_message` and `unread_count` |
| `GET /api/chat/conversations/{id}` | One conversation (participants only) |
| `GET /api/chat/conversations/{id}/messages?page&page_size` | Messages, newest first, paginated |
| `POST /api/chat/conversations/{id}/messages` | Send `{body}` |
| `POST /api/chat/conversations/{id}/read` | Mark messages from the other person as read |
| `GET /api/chat/unread-count` | Total unread + `poll_interval_seconds` |
| `GET /api/community/posts?category&author_id&q&page&page_size` | Feed (newest first) with like/comment counts and `liked_by_me` |
| `POST /api/community/posts` | Create `{title, body, category}` |
| `GET / PUT / DELETE /api/community/posts/{id}` | Read / edit (author) / delete (author or admin) |
| `POST / DELETE /api/community/posts/{id}/image` | Attach (multipart `file`, JPEG/PNG/WebP, max 5 MB) / remove the image (author) |
| `POST / DELETE /api/community/posts/{id}/like` | Like / unlike (idempotent) |
| `GET / POST /api/community/posts/{id}/comments` | List (oldest first, paginated) / add a comment |
| `PUT / DELETE /api/community/comments/{id}` | Edit (author) / delete (author or admin) |
| `POST /api/issue-reports` | Report `{target_type: post\|comment\|user\|listing, target_id, reason, details?}`. 409 if you already have an open report on it |
| `GET /api/issue-reports/my` | My reports |
| `GET /api/issue-reports?status&target_type&page` | Admin: list with reporter and a preview of the target |
| `GET /api/issue-reports/{id}` | Reporter or admin |
| `PATCH /api/issue-reports/{id}/status` | Admin: `{status, admin_note?}` following the workflow above |

Categories: `general`, `crops`, `pests_diseases`, `weather`, `market`, `equipment`, `other`. Reasons: `spam`, `harassment`, `inappropriate`, `misinformation`, `scam`, `other`.

### Flutter screens

Community Feed, Post Details (with comments), Create/Edit Post, Conversations, Chat, Report dialog, Admin Reports. The dashboard has Community and Chats tiles, plus a Review Reports tile for admins. Other modules can start a chat with `openChatWith(context, userId, listingId: ...)` from `features/chat/chat_launcher.dart`, and open the report dialog with `showReportDialog(...)` from `features/issue_reports/widgets/report_dialog.dart`.

---

## Important notes on the AI features

**The disease and pest detection models are mocks.** No trained model exists yet. The mock backend is deterministic (same image always gives the same result), and every API response carries `is_mock_result: true` plus a disclaimer. The Flutter UI shows a visible "demo mode" notice for mock results. It must not be presented as a real trained model.

To plug in a real model later:

1. Add a class implementing `predict(image_bytes)` in `backend/app/services/disease_model_service.py` (or `pest_model_service.py`)
2. Register it in `get_disease_model_service()` / `get_pest_model_service()`
3. Set `DISEASE_MODEL_BACKEND` / `PEST_MODEL_BACKEND` in `.env`

No router, schema, or Flutter code needs to change.

**Crop recommendation is a transparent rule-based scoring engine**, not a trained ML model. It scores 8 common Sri Lankan crops against soil pH, temperature, rainfall, water availability, and season, and explains every score. It is decision support, not guaranteed agricultural advice.

**Weather** uses OpenWeatherMap when `WEATHER_API_KEY` is set. Without a key (or if the external API fails), it falls back to a clearly labelled mock response so the app still works.

---

## Quick start

### Prerequisites (macOS)

- Flutter SDK, VS Code with the Flutter + Dart extensions
- Android Studio (Android SDK + emulator)
- Python 3.12+
- PostgreSQL 16

```bash
brew install postgresql@16
brew services start postgresql@16
flutter doctor
```

### 1. Backend

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # edit DATABASE_URL and JWT_SECRET_KEY

createuser agrinexus_user -P    # password: changeme (or update .env to match)
createdb agrinexus_db -O agrinexus_user

alembic upgrade head          # creates all tables (Modules 1, 2 and 3)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Check `http://localhost:8000/health`.

### 2. Frontend

```bash
cd frontend
flutter create --platforms=android --org com.agrinexus --project-name agrinexus_farmer .   # only if android/ is missing
flutter pub get
flutter analyze
```

Android permissions (internet, camera) are already in `android/app/src/main/AndroidManifest.xml`; debug builds also allow plain-HTTP to the local backend.

Run against the backend (the base URL differs per platform):

```bash
# Android emulator (no flag needed: defaults to http://10.0.2.2:8000, the emulator's alias for your Mac)
flutter run -d android

# Physical Android phone: use your Mac's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000
```

### 3. Tests (backend)

```bash
createdb agrinexus_test_db -O agrinexus_user
export TEST_DATABASE_URL=postgresql://agrinexus_user:changeme@localhost:5432/agrinexus_test_db
cd backend && pytest app/tests/ -v
```

---

## Verification status

| Area | Status |
|---|---|
| Backend tests | 47/47 passing against real PostgreSQL 16 (Modules 1, 2 and 3) |
| Migrations | `alembic upgrade head` / `downgrade -1` / `upgrade head` verified on a fresh DB; `alembic check` clean |
| Backend live smoke test | Register, login, weather, crop recommendation, farm creation verified against a running server |
| Frontend ↔ backend contract | Every API path and request/response field checked against the backend schemas |
| Flutter static analysis | `flutter analyze`: 0 errors (warnings and deprecation infos remain in earlier modules) |
| Flutter app run | **Not yet verified on a device/emulator**: run `flutter run` before demoing |

---

## Integration notes for Members 2 and 3

- **One shared `users` table.** `backend/app/models/user.py` is the single user table. `UserRole` already includes `buyer` and `community_member`. Do not create a second user system; reference `users.id` (UUID) as a foreign key.
- **Shared infrastructure.** `backend/app/database.py` defines `Base`, `get_db`, and the engine. `backend/app/core/dependencies.py` provides `get_current_user` and `require_role(...)`. Reuse them.
- **Dependency pins matter.** `bcrypt==4.0.1` is pinned because `passlib==1.7.4` breaks with newer bcrypt versions (every register/login fails). Don't upgrade it independently.
- **Frontend shared code.** Put cross-cutting code under `frontend/lib/shared/`. Reuse `ApiClient`, `TokenStorage`, and the common widgets rather than duplicating them.
- **Localization.** All user-facing strings go through the ARB files in `frontend/lib/shared/l10n/` (English, Sinhala, Tamil). Don't hard-code strings in widgets.
- **Route ownership.** Don't add Marketplace or Community routes under Module 1's prefixes, and don't edit another member's module.

---

## Git workflow

```bash
git checkout -b member1/farmer-ai        # your module branch
git add backend/ frontend/
git commit -m "Module 1: Farmer + AI Agriculture"
git push origin member1/farmer-ai
```

Open a pull request into `main` when a module is ready. Pull `main` regularly so shared files (`database.py`, `requirements.txt`, `pubspec.yaml`) don't drift.

---

## Environment variables

Copy `backend/.env.example` to `backend/.env`. Never commit `.env` or hard-code keys.

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (shared with other modules) |
| `JWT_SECRET_KEY` | Secret for signing tokens — use a long random value |
| `ACCESS_TOKEN_EXPIRE_MINUTES` / `REFRESH_TOKEN_EXPIRE_DAYS` | Token lifetimes |
| `WEATHER_API_KEY` | OpenWeatherMap key (optional; mock fallback without it) |
| `DISEASE_MODEL_BACKEND` / `PEST_MODEL_BACKEND` | `mock` now; set to your backend name when a real model exists |
| `CORS_ORIGINS`, `UPLOAD_DIR` | CORS allow-list and image upload folder |
| `COMMUNITY_UPLOAD_DIR` / `COMMUNITY_UPLOAD_URL_PREFIX` | Where community post images are stored and served (local storage) |
| `CHAT_POLL_INTERVAL_SECONDS` / `CHAT_PAGE_SIZE_MAX` | How often the app polls for new chat messages; max messages per page |

---

## Known limitations

- Logout revokes tokens in an in-memory set (fine for a single dev server; use Redis or a DB table for production)
- Uploaded images are stored on local disk under `uploads/`
- The dev setup uses plain HTTP; use HTTPS before any real deployment
- Flutter app has not been run on a device or emulator yet (see Verification status)
- Chat uses polling, so new messages can take up to `CHAT_POLL_INTERVAL_SECONDS` to appear
