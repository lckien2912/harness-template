```bash
# Project (uv shown; Poetry: poetry install / poetry run ...)
uv sync
uv run ruff check . && uv run ruff format --check .
uv run mypy .
uv run pytest -q -m "not integration"
uv run pytest -q -m integration
```
