import os
import tempfile
from pathlib import Path

# Set test config before importing application (settings created on import).
_temp = tempfile.TemporaryDirectory()
os.environ["DATABASE_URL"] = f"sqlite:///{Path(_temp.name) / 'test.db'}"
os.environ["SECRET_KEY"] = "test-secret-for-automated-tests-only"

from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402


def test_foodwise_end_to_end():
    with TestClient(app) as client:
        assert client.get("/health").status_code == 200
        user = {"name": "Test User", "email": "test@example.com", "password": "StrongPassword123"}
        assert client.post("/auth/register", json=user).status_code == 201
        login = client.post("/auth/login", json={"email": user["email"], "password": user["password"]})
        assert login.status_code == 200
        h = {"Authorization": f"Bearer {login.json()['access_token']}"}
        food = client.post("/foods", headers=h, json={"name": "Cooked rice", "calories": 130, "protein": 2.7, "carbs": 28, "fat": 0.3})
        assert food.status_code == 201
        assert client.get("/foods", headers=h).status_code == 200
        meal = client.post("/meals", headers=h, json={"food_id": food.json()["id"], "meal_type": "lunch", "quantity_grams": 150, "eaten_on": "2026-10-12"})
        assert meal.status_code == 201
        summary = client.get("/meals/summary?on=2026-10-12", headers=h)
        assert summary.status_code == 200
        assert float(summary.json()["calories"]) == 195.0
        assert client.delete(f"/meals/{meal.json()['id']}", headers=h).status_code == 204
        assert client.get("/foods").status_code in (401, 403)
