# Testing Standards

## TDD Requirement

New features and bug fixes SHOULD follow TDD:
1. **RED**: Write a failing test first
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while tests stay green

## Coverage Targets

- New code: 80% minimum
- Critical paths (auth, API, data processing): 90%
- Existing code: maintain current coverage, never decrease

## Test Structure

```
tests/
├── unit/           # Fast, isolated, mocked dependencies
├── integration/    # With real services (Docker)
└── conftest.*      # Shared fixtures / setup
```

## Test Naming

- `test_<behavior>_<scenario>` — e.g., `test_search_returns_empty_for_unknown_query`
- One assertion per test (prefer)
- Descriptive failure messages

## Mocking Rules

- Mock external services (databases, HTTP APIs, message queues)
- Never mock the code under test
- Use fixtures for common setup

## Pre-Commit Test Requirements

Per CLAUDE.md §3: Run tests before any commit.
Tests are auto-detected by file type in pre-commit-gate.sh.
