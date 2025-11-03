# Simple Python Test Fixture

This is a minimal Python project for testing spectacular commands.

## Development Commands

### Setup

- **install**: `pip install -r requirements.txt`
- **postinstall**: None (no codegen needed)

### Quality Checks

- **test**: `pytest`
- **lint**: `ruff check .`
- **format**: `black .`
- **build**: `python -m py_compile src/main.py`

## Project Structure

- `src/main.py` - Main module with simple arithmetic functions
- `src/test_main.py` - Basic tests for functions
- `requirements.txt` - Dependencies
