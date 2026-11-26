- **Application:** <Django / FastAPI / Flask> on Python <version>, in `<path>`.
- **Datastore:** <database> via <Django ORM / SQLAlchemy + Alembic>.
- **Tooling:** the lockfile names the runner (`uv.lock` → uv,
  `poetry.lock` → Poetry); exactly one exists. Dependencies are declared in
  `pyproject.toml`; never `pip install` into the project by hand.
- **Quality:** ruff (lint + format), mypy, pytest. Tests that need live
  services are marked `@pytest.mark.integration`.
