# Contributing Guidelines

Thank you for your interest in contributing to this project! Following these guidelines helps maintain consistency and ensures a smooth collaboration process.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Setting Up the Development Environment](#setting-up-the-development-environment)
  - [Python](#python)
  - [Lua](#lua)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Contributing Workflow](#contributing-workflow)
- [Common Commands](#common-commands)
- [Contact](#contact)

---

## Getting Started

1. Fork the repository and clone it to your local machine:

   ```bash
   git clone https://github.com/<YOUR_USERNAME>/RPGLootFeed.git
   cd RPGlootFeed
   ```

2. Review the [issues](https://github.com/McTalian-WoW-Addons/RPGLootFeed/issues) to find something you'd like to work on, or propose a new feature by creating an issue.

---

## Setting Up the Development Environment

### Python

1. **Install uv**  
   uv is used for Python dependency and environment management:

   [Install uv](https://docs.astral.sh/uv/getting-started/installation/)

2. **Install Dependencies**  
   Install project dependencies into a virtual environment:

   ```bash
   uv sync
   ```

3. **Run Scripts**  
   Use `make` to execute project-specific scripts, such as:
   ```bash
   make hardcode_string_check
   make missing_translation_check
   make all_checks
   make test
   ```

### Lua

1. **Install Lua**  
   Install Lua using your package manager or `luaenv`:
   ```bash
   luaenv install
   ```
1. **Install LuaRocks**  
   [Install Luarocks for package management.](https://github.com/luarocks/luarocks?tab=readme-ov-file#installing)
1. **Install Dependencies**  
   Install project dependencies via `make`:
   ```bash
   make lua_deps
   ```
1. **Verify Installation**  
   Ensure the tools are available:
   ```bash
   lua -v
   ~/.luarocks/bin/busted --version
   ```

---

## Code Standards

Run [trunk](https://trunk.io) checks to ensure your code meets the project's standards:

```bash
./trunk fmt
./trunk check
```

---

## Testing

### Packaging

- Use `make dev` to package the project for local testing:

  ```bash
  make dev
  ```

This will create an alpha build in the `.release` directory. It is recommended that you create a symlink to this directory in your game's `Interface/Addons` directory so that the latest changes are immediately available in the game after a `/reload`.

- Smoke tests are run automatically upon loading an alpha build of the addon (on login or `/reload`).
- Run `/rlf i` in the game to run integration tests (you will see a failure if you looted anything since the last `/reload` or if you already ran the integration tests since "loot history" is part of the integration tests).

### Lua Tests

- Use `make test` for unit tests:

  ```bash
  make test
  ```

- Generate coverage reports:
  ```bash
  make test-cov
  ```

---

## Contributing Workflow

1. **Create a Feature Branch**  
   Branch from `main` and name your branch descriptively:

   ```bash
   git checkout -b feature/your-feature
   ```

1. **Test Your Changes**  
   Run all checks and tests before opening a pull request:

   ```bash
   make all_checks
   make test
   ```

1. **Submit a Pull Request**
   - Push your branch:
     ```bash
     git push origin feature/your-feature
     ```
   - Open a pull request to `main` with a clear title and description of your changes.

---

## Common Commands

### Development Commands

| Command                          | Description                                 |
| -------------------------------- | ------------------------------------------- |
| `make hardcode_string_check`     | Checks for hard-coded strings in Lua files. |
| `make missing_translation_check` | Detects missing translations in Lua files.  |
| `make test`                      | Runs Lua unit tests.                        |
| `trunk check`                    | Lints all files.                            |

### Cleanup Commands

| Command                                    | Description               |
| ------------------------------------------ | ------------------------- |
| `rm -rf luacov-html && rm -rf luacov.*out` | Cleans up coverage files. |

---

## Contact

If you have any questions or need help, feel free to reach out by creating an issue in the repository.

AI tooling: see CLAUDE.md.

---
