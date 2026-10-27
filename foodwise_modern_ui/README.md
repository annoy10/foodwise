# FoodWise: RAG Chat (No Scanner)

This package updates the **user-uploaded** nutrition-oriented FoodWise project. Existing nutrition tracker pages are preserved. A **manual-ingredient RAG chatbot** was added; there is no scanner. The existing food catalog is not a quantity-aware household pantry inventory. The chat uses the ingredients entered into its textbox, not stock records.

## Stack
Flutter UI, FastAPI/Pydantic/SQLAlchemy, PostgreSQL 16 + pgvector via Docker, LangChain ChatOllama + OllamaEmbeddings, local Ollama (qwen2.5:3b and nomic-embed-text).

## Windows setup
1. Install Docker Desktop and start it. Install Python 3.11+ and Flutter SDK. Ollama must be running on host.
2. In `backend` PowerShell: `docker compose up -d`
3. In terminal: `ollama pull qwen2.5:3b` and `ollama pull nomic-embed-text`
4. In `backend`: `Copy-Item .env.example .env`. Edit `SECRET_KEY` to a random secure value. DB credentials in compose are for **local development only**.
5. In `backend`:
   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   python -m app.seed_recipes
   uvicorn app.main:app --reload
   ```
6. Open `http://127.0.0.1:8000/docs`. Register/login and use `POST /chat` with Bearer token. Example: `{"message":"আমার কাছে ডিম, আলু ও টমেটো আছে, কী রান্না করতে পারি?"}`
7. In `mobile`: `flutter create --platforms=android --project-name foodwise .`, `flutter pub get`, `flutter run`.
8. For local Android HTTP development enable `android:usesCleartextTraffic="true"` in AndroidManifest's `<application>` (only for development). Default Android emulator API base URL is `http://10.0.2.2:8000`. For a physical phone use `--dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000` and run uvicorn with `--host 0.0.0.0`, only on a trusted LAN.

## RAG
Run `python -m app.seed_recipes` after the Ollama embedding model is pulled. Recipe seed contains 15 sample recipes. pgvector requires `vector(768)` for `nomic-embed-text`. RAG queries vector similarity in PostgreSQL then uses LangChain ChatOllama to answer using retrieved recipe text. This is a **prototype**, not a clinically validated food safety assistant. Avoid sharing private data with other users.

## Files
- Backend `app/routers/chatbot.py`, `app/services/rag_service.py`, `app/models/recipe.py`, `app/seed_recipes.py`, `data/recipes.json`
- Mobile `lib/screens/rag_chat_screen.dart`, `lib/services/api.dart`
- PostgreSQL `backend/docker-compose.yml`

## Testing status
Python syntax and zip structure can be checked here; a live Flutter build or Ollama + PostgreSQL end-to-end test requires local services.
