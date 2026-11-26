- Virtualenvs, caches and build output: `.venv/`, `__pycache__/`,
  `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `build/`, `dist/`.
- Lockfiles: change them only through uv/Poetry.
- Existing migrations: never rewrite one; add a new migration instead.
