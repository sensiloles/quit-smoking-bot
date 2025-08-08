# 🤖 CLI Specification: Telegram Bot Manager

## Purpose

Evolution of the repository into a professional Python CLI solution for developing and deploying Telegram bots. Goal — automation of the complete lifecycle: from initialization to production deployment.

**📊 Current Status:**

- ✅ Core CLI infrastructure (`manager.py` + `scripts/`)
- ✅ Production-ready Docker environment
- ⚠️ SSH client and VPS deployment (required for MVP)

**🎯 MVP Priorities:**

1. SSH client and automatic VPS deployment
2. Versioning with commitizen
3. CI/CD templates and extensions

## 📊 Architecture

### ✅ Implemented

**Components:**

- `manager.py` — unified CLI interface
- `scripts/` — modular system (actions, docker_utils, health, environment)
- `src/` — production-ready Telegram bot
- `docker/` — containerization with monitoring

**Commands:**

```bash
python manager.py setup/dev-setup    # Environment setup
python manager.py start/stop/restart # Service management
python manager.py status/logs        # Monitoring and diagnostics
python manager.py clean --deep       # Resource cleanup
```

### ⚠️ Requires Implementation

**Missing Modules:**

- `ssh_client.py` — secure VPS connection
- `deploy.py` — deployment automation
- `version.py` — semantic versioning

## 🎯 Target Architecture

**CLI Purpose:** `tgbot-manager` (alias: `tgm`)

- Project and development environment initialization
- Lifecycle management (run/stop/deploy)
- Configuration and versioning
- VPS deployment with automation

**Requirements:**

- Compatibility: macOS, Linux, WSL2
- Docker-first approach for all environments
- Security: no secrets in VCS, variable validation
- Distribution: Python package → PyPI

## 📋 Technical Requirements

**Core:**

- Python >= 3.9, pyproject.toml (PEP 621)
- Quality: ruff (lint+format), mypy, pre-commit hooks
- Security: variable validation, secrets outside VCS

**Current Structure:**

```text
project/
  src/          # ✅ Production-ready bot
  scripts/      # ✅ Modular CLI system
  docker/       # ✅ Containerization
  data/logs/    # ✅ Persistent storage
  tests/        # ⚠️ Needs expansion
```

## 💻 CLI Functionality

### MVP Commands

**Implemented ✅:**

- `tgm init/doctor` — initialization and environment check
- `tgm run/docker` — local startup and container management
- `tgm status/logs` — monitoring and diagnostics

**Required ⚠️:**

- `tgm deploy vps` — automatic VPS deployment
- `tgm version bump` — semantic versioning

### Extended Capabilities

- Secret and configuration management
- CI/CD templates for popular platforms
- SSH fingerprint validation

## 🛠️ Development Environment

**Dependencies:**

- ✅ Core: `python-telegram-bot`, `APScheduler`, `python-dotenv`
- ✅ Dev: `ruff`, `mypy`, `pytest`, `pre-commit`, `commitizen`
- ⚠️ VPS: `paramiko` for SSH connections

**Quick Start:**

```bash
make dev-setup    # Development environment setup
make start        # Launch in Docker
make start-local  # Local launch (requires .env)
```

---

## CI/CD for VPS

### Basic Strategy

- **CI** (e.g., GitHub Actions):
  - triggers: PR, push to main, release tags,
  - steps: checkout → Python setup → `ruff/mypy/pytest` → Docker image build → push to registry (GHCR/Docker Hub) → deploy to VPS (via secure channel).
- **CD**:
  - on VPS execute `docker compose pull && docker compose up -d`,
  - service health-check,
  - on error — automatic `rollback` (store previous tag/compose override).

### VPS Connection Module (SSH/Secure Alternatives)

Requirements for `ssh_client` module:

- Supported authentication methods:
  - SSH key (recommended),
  - password (forbidden in CI, allowed only interactively with warning),
  - via bastion/jump-host (`ProxyCommand` or SSH ProxyJump),
  - `known_hosts` check and fingerprint pinning.
- Input parameter validation: host, port, user, key/agent path, known_hosts policies.
- Test connection (`tgm vps test`):
  - handshake check and user permissions,
  - Docker/Compose availability check on target machine,
  - disk space and system limits check (optional).
- Security:
  - prohibition of secret logging,
  - optional ssh-agent integration,
  - ability to work via system `ssh` (subprocess) or pure Python (e.g., `asyncssh`), depending on environment.

### Automatic Deployment (CLI)

`tgm deploy vps` flow:

1. Environment and secrets check.
2. Docker image build and tagging (SemVer + git sha).
3. Registry publication (GHCR or Docker Hub).
4. Compose files/override delivery to server (scp/rsync or git pull on server).
5. Remote command execution: `docker compose pull && docker compose up -d`.
6. Health-check and version verification.
7. Optional `rollback` to previous tag.

Example minimal GitHub Actions workflow (fragment):

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install -e .[dev]
      - run: ruff check . && ruff format --check . && mypy .
      - run: pytest -q
  release-deploy:
    needs: build-test
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -e .[dev]
      - name: Build and push image
        run: |
          echo "$CR_PAT" | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin
          docker build -t ghcr.io/ORG/BOT_IMAGE:${GITHUB_REF_NAME} -f docker/Dockerfile .
          docker push ghcr.io/ORG/BOT_IMAGE:${GITHUB_REF_NAME}
      - name: Deploy via CLI
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
        run: tgm deploy vps --image ghcr.io/ORG/BOT_IMAGE:${GITHUB_REF_NAME}
```

---

## MVP: Minimum Viable Product

### Bot Functionality ✅ **IMPLEMENTED**

- ✅ Launch in polling mode.
- ✅ `/start` command with greeting and user registration.
- ✅ Event logging; error handling with log notifications.
- ✅ Daily notification scheduling (via `APScheduler`).
- ✅ Administrator system and user management.
- ✅ Progress tracking and prize fund calculation.

### CLI Functionality

- ✅ **Implemented**: `setup` (init), `check-env` (doctor), `start` (run), `docker up/down/logs`, `status`, basic operations.
- ⚠️ **Require implementation**: `deploy vps` with SSH module, extended `version` management.

### MVP Readiness Criteria

- ✅ Bot launch locally and in Docker.
- ✅ Passing linters and basic tests.
- ✅ Comprehensive health monitoring and status diagnostics.
- ⚠️ **Remaining for MVP**: Automatic VPS deployment with single command `manager.py deploy vps`.

---

## Versioning (GitHub)

- **Schema**: Semantic Versioning (SemVer).
- **Tool**: commitizen for version `bump` and tag/CHANGELOG generation.
- **Version storage**: in `pyproject.toml` → read by CLI command `tgm version`.
- **Release process**:
  1. Merge to `main` with conventional commit.
  2. `tgm version bump [patch|minor|major]` → commit + tag.
  3. CI: tests → image build and push → VPS deploy.
  4. GitHub Release publication (automatically from tags).

---

## DEVELOPMENT_LOG.md for Cursor

Requirements for `DEVELOPMENT_LOG.md` file:

- Structure convenient for Cursor and regular updates (synergy with `.cursorrules`).
- Recommended template:

```markdown
## Stage

- active/frozen/release-candidate

## Done

- brief list of key changes (with dates, links to PR/commits)

## In Progress / Next

- next sprint tasks; clear items with links to files/modules

## Decisions and Rationale

- architectural decisions, compromises, why exactly this way

## Open Questions/Risks

- what blocks, what requires separate investigation

## Technical Debt

- what needs refactoring and when
```

- Update file along with any significant code and infrastructure changes.
- Do not store secrets or sensitive information.

---

## 🚀 CLI Architecture Improvements Based on Best Practices

### Key Improvements

**Framework:** Click (mature, widely used) or Typer (modern, type hints)

**Advantages:**

- Automatic help generation and validation
- Nested commands and groups
- Rich integration for beautiful UI
- Plugin system for extensions

### New Command Structure

**Hierarchical commands (following Poetry/Git pattern):**

```bash
tgm service start --monitoring    # Service management
tgm deploy vps --strategy rolling # Deployment
tgm config set bot.token VALUE    # Configuration
tgm template init --type advanced # Templates
```

**Configuration via pyproject.toml:**

```toml
[tool.tgbot-manager.bot]
token_env = "BOT_TOKEN"
admin_chat_id = 123456789

[tool.tgbot-manager.deployment]
vps_host = "example.com"
docker_registry = "ghcr.io"
```

**Plugin system:**

```python
class MonitoringPlugin(TgBotPlugin):
    def commands(self): return [self.metrics_command]
    def hooks(self): return {"before_start": self.setup}
```

### New Structure

```text
src/tgbot_manager/
  cli.py                # Main entry point
  commands/             # Command modules
    service.py          # Service management
    deploy.py           # Deployment
    config.py           # Configuration
  core/                 # Core functionality
    ssh.py              # SSH client
    deploy.py           # Deployment logic
    version.py          # Versioning
  plugins/              # Plugin system
  templates/            # Project templates
    basic/              # Basic bots
    advanced/           # Advanced bots
```

### Click-based Design Example

**Main CLI:**

```python
# cli.py
import click
from rich.console import Console

@click.group()
@click.option('--verbose', '-v', is_flag=True)
@click.option('--dry-run', is_flag=True)
def cli(verbose, dry_run):
    """🤖 Telegram Bot Manager"""
    # Context for parameter passing
    pass

@cli.command()
def init():
    """🚀 Initialize project"""
    pass

@cli.group()
def service():
    """🚀 Service management"""
    pass

@service.command()
@click.option('--monitoring', is_flag=True)
def start(monitoring):
    """Start bot service"""
    with Progress() as progress:
        # Rich progress bars
        pass
```

**Advantages:**

- Automatic `--help` generation
- Nested commands and groups
- Rich UI for beautiful output
- Typing and validation

### Configuration with Validation

```python
# config.py - Pydantic validation
from pydantic import BaseSettings, Field

class BotConfig(BaseSettings):
    # Bot settings
    token: str = Field(..., description="Bot token")
    admin_chat_id: Optional[int] = None

    # Deployment
    vps_host: Optional[str] = None
    docker_registry: str = "ghcr.io"

    # Monitoring
    enable_metrics: bool = False
    log_level: str = "INFO"

    @validator('token')
    def validate_token(cls, v):
        if not v or len(v) < 10:
            raise ValueError('Invalid token')
        return v

    class Config:
        env_prefix = 'TGBOT_'
        env_file = '.env'

def load_config() -> BotConfig:
    """Load from pyproject.toml + environment"""
    # Configuration merging
    return BotConfig()
```

### Plugin System

```python
# plugins/base.py
from abc import ABC, abstractmethod

class TgBotPlugin(ABC):
    @property
    @abstractmethod
    def name(self) -> str: pass

    @abstractmethod
    def commands(self): pass

    def hooks(self): return {}

# plugins/monitoring.py
class MonitoringPlugin(TgBotPlugin):
    def name(self) -> str:
        return "monitoring"

    def commands(self):
        @click.command()
        def metrics():
            """📊 Show metrics"""
            # Implementation
            pass
        return [metrics]

    def hooks(self):
        return {
            "before_start": self.setup_monitoring
        }
```

### Template System

```python
# template.py - Jinja2 templates
class TemplateEngine:
    def __init__(self, templates_dir):
        self.templates_dir = templates_dir
        self.jinja_env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(templates_dir)
        )

    def create_project(self, template_name: str,
                      target_dir: Path, context: dict):
        """Create project from template"""
        template_dir = self.templates_dir / template_name

        for src_file in template_dir.rglob('*'):
            if src_file.is_file():
                # Process with Jinja2
                template = self.jinja_env.get_template(rel_path)
                content = template.render(**context)
                dst_file.write_text(content)

    def list_templates(self):
        """Available templates"""
        return [d.name for d in self.templates_dir.iterdir()]
```

**Templates:**

- `basic/` — simple bot with polling
- `advanced/` — webhook + database
- `enterprise/` — monitoring + scaling

### Testing

```python
# conftest.py - Click test runner
from click.testing import CliRunner

@pytest.fixture
def runner():
    return CliRunner()

@pytest.fixture
def temp_project(tmp_path):
    return tmp_path / "test_bot"

# test_cli.py
def test_init_command(runner, temp_project):
    result = runner.invoke(cli, ['init', '--name', 'test-bot'])
    assert result.exit_code == 0
    assert "initialized" in result.output

def test_full_workflow(runner, temp_project):
    # Init → Doctor → Start (dry-run)
    runner.invoke(cli, ['init'])
    runner.invoke(cli, ['doctor'])
    result = runner.invoke(cli, ['service', 'start', '--dry-run'])
    assert result.exit_code == 0
```

**Test Types:**

- Unit: component module tests
- Integration: CLI command tests
- E2E: full scenarios with Docker

### Performance Optimizations

**Lazy Loading:**

```python
class LazyGroup(click.Group):
    def get_command(self, ctx, cmd_name):
        # Import only when needed
        module = importlib.import_module(f'commands.{cmd_name}')
        return getattr(module, cmd_name)
```

**Rich UI:**

```python
from rich.console import Console
from rich.table import Table

def show_status_table(services):
    table = Table(title="🤖 Services Status")
    table.add_column("Service", style="cyan")
    table.add_column("Status", style="green")

    for service, status in services.items():
        table.add_row(service,
            "🟢 Running" if status else "🔴 Stopped")

    console.print(table)
```

**Progress Bars:**

```python
with Progress() as progress:
    task = progress.add_task("Deploying...", total=100)
    # Operations with progress updates
```

### International Support

```python
# i18n.py - gettext support
class I18nManager:
    def __init__(self, locale_dir, default='en'):
        self.translations = self._load_translations(locale_dir)

    def get_text(self, message, locale=None):
        locale = locale or self.default_locale
        return self.translations.get(locale, {}).get(message, message)

# Usage
def _(msg): return i18n.get_text(msg)

@cli.command()
def start():
    console.print(_("🚀 Starting bot service..."))
```

### Security

```python
# security.py
class SecurityManager:
    @staticmethod
    def validate_ssh_key(key_path) -> bool:
        """Validate SSH key format"""
        with open(key_path) as f:
            content = f.read()
            return '-----BEGIN' in content and 'PRIVATE KEY-----' in content

    @staticmethod
    def mask_sensitive_data(data: str, show=4) -> str:
        """Mask sensitive data: token123...xyz789"""
        if len(data) <= show * 2:
            return '*' * len(data)
        return f"{data[:show]}{'*' * (len(data) - show * 2)}{data[-show:]}"

# Usage example
masked_token = SecurityManager.mask_sensitive_data(config.bot_token)
console.print(f"Token: {masked_token}")
```

### Deployment Strategies

```python
# deploy_strategies.py
class DeploymentStrategy(ABC):
    @abstractmethod
    def deploy(self, config) -> bool: pass
    @abstractmethod
    def rollback(self, version) -> bool: pass

class RollingDeployment(DeploymentStrategy):
    def deploy(self, config):
        # 1. Update one instance at a time
        # 2. Health check each
        # 3. Continue or rollback
        pass

class BlueGreenDeployment(DeploymentStrategy):
    def deploy(self, config):
        # 1. Deploy to green environment
        # 2. Switch traffic
        pass

# Usage
@click.option('--strategy', default='rolling')
def deploy_vps(strategy):
    strategies = {
        'rolling': RollingDeployment(),
        'blue-green': BlueGreenDeployment()
    }
    strategies[strategy].deploy(config)
```

### PyPI Distribution

```toml
# pyproject.toml - PyPI configuration
[project]
name = "tgbot-manager"
dynamic = ["version"]
description = "Telegram Bot Development & Deployment Toolkit"
requires-python = ">=3.9"

dependencies = [
    "click>=8.1.0",
    "rich>=13.0.0",
    "pydantic>=2.0.0",
    "python-telegram-bot>=22.0.0",
    "docker>=6.0.0",
    "paramiko>=3.0.0"
]

[project.optional-dependencies]
dev = ["pytest", "ruff", "mypy", "pre-commit"]
monitoring = ["prometheus-client"]
cloud = ["boto3", "google-cloud-run"]

[project.scripts]
tgm = "tgbot_manager.cli:cli"
tgbot-manager = "tgbot_manager.cli:cli"

[tool.hatch.version]
source = "vcs"
```

### CI/CD Templates

```yaml
# github-actions.yml template
name: 🤖 Bot CI/CD

on:
  push: { branches: [main] }
  release: { types: [published] }

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.9", "3.11"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with: { python-version: "${{ matrix.python-version }}" }
      - run: pip install -e .[dev]
      - run: pytest tests/ -v

  deploy:
    needs: test
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          docker build -t $IMAGE .
          docker push $IMAGE
          tgm deploy vps --image $IMAGE
    env:
      VPS_HOST: ${{ secrets.VPS_HOST }}
      VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
```

### Monitoring

```python
# observability.py - Prometheus metrics
from prometheus_client import Counter, Histogram, start_http_server

command_executions = Counter('tgm_commands_total',
                            'Total commands', ['command', 'status'])
command_duration = Histogram('tgm_command_duration_seconds',
                           'Command time', ['command'])

def monitor_command(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            command_executions.labels(func.__name__, 'success').inc()
            return result
        except Exception:
            command_executions.labels(func.__name__, 'error').inc()
            raise
        finally:
            duration = time.time() - start_time
            command_duration.labels(func.__name__).observe(duration)
    return wrapper

# Usage
@cli.command()
@monitor_command
def start(): pass

@cli.command()
def metrics(port=8000):
    start_http_server(port)
    console.print(f"📊 Metrics on :{port}/metrics")
```

## 🗺️ Implementation Roadmap

### MVP (2-3 weeks)

- Click framework migration
- SSH client and VPS deploy
- Pydantic configuration
- Comprehensive testing

### Professional (2-3 weeks)

- Plugin system and template engine
- Rich UI integration
- Advanced deployment strategies
- CI/CD templates

### Enterprise (2-4 weeks)

- Internationalization (i18n) support
- Observability and monitoring
- PyPI publication and documentation

**Readiness Criteria:**

- MVP: Click CLI + SSH deploy + tests
- Professional: Plugin system + Rich UI + deployment strategies
- Enterprise: i18n + observability

---

## Extensibility: Telegram API Abstraction (Future)

- Design adapter layer over `python-telegram-bot` for command/handler unification.
- Think through "plugins"/extensions: notifications, pipelines, integrations (DB, queues, payments).
- CLI should be able to template module/handler scaffolds.
- At this stage — only requirements and templates; postpone implementation until basic CLI stabilization.

## 📋 Conclusion

### Enhanced Architecture Benefits

**For Developers:** Professional CLI + plugin system + Rich UI
**For DevOps:** Advanced deployment + monitoring + CI/CD templates
**For Users:** Auto-documentation + template system + extended functionality

### Key Improvements

| Characteristic    | Current     | Enhanced         | Growth   |
| ----------------- | ----------- | ---------------- | -------- |
| **UX/DX**         | Functional  | Professional     | **300%** |
| **Extensibility** | Limited     | Plugin ecosystem | **500%** |
| **Monitoring**    | Logs        | Observability    | **600%** |
| **Deployment**    | Docker only | Multi-strategy   | **300%** |

### Evolution: MVP → Professional → Enterprise

1. **MVP (2-3 months):** Click + SSH + Pydantic + testing
2. **Professional (3-6 months):** Plugin system + Rich UI + deployment strategies
3. **Enterprise (6+ months):** i18n + observability + PyPI

### Competitive Advantages

After implementation, tgbot-manager will become:

- Better than Poetry in Telegram specialization
- Competitor to Heroku CLI in deployment convenience
- Unique in the Telegram development ecosystem

### Implementation Priorities

**Immediately (1-2 weeks):** Click migration + SSH module
**Short-term (1 month):** Template engine + Rich UI + testing
**Medium-term (2-3 months):** Plugin system + deployment strategies

**Next step:** Select priority modules and start implementation.

## 🐳 Docker as Foundation

- Single `Dockerfile` (multi-stage) for dev and prod.
- `docker-compose.yml` for local development; `.env` loaded from root.
- On VPS — same compose file or derivative configuration (`docker-compose.prod.yml`).
- Image requirements:
  - minimal base (e.g., `python:3.11-slim`),
  - non-root user,
  - healthcheck,
  - dependency caching (`pip wheel`/`--mount=type=cache`).

---

## Additional Technologies (As Needed)

- **SSH**: system `ssh` client (default), optionally `asyncssh` for pure Python wrapper.
- **Artifact transport**: `rsync` (if available) or `scp`.
- **Logs/monitoring**: integration with `docker logs`/`journalctl`, future — Prometheus/Grafana, ELK/OpenSearch.
- **Tests**: `pytest`, `pytest-asyncio`, `pytest-docker` (for integrations), network call mocks.

---

## Quality and Security Checklist

- **Code**: ruff clean, mypy clean, tests green.
- **Secrets**: tokens stored outside VCS; `.env` not tracked by git.
- **Documentation**: README, REQUIREMENTS, DEVELOPMENT_LOG up to date.
- **Docker**: reproducible build, minimal image, healthcheck.
- **CI/CD**: tag rollback, `main` branch protection, mandatory checks.
- **VPS**: SSH keys, password restrictions, fingerprint pinning, security updates.

---

## CLI Usage Examples (Scenarios)

```bash
# Initialization and validation
tgm init
tgm doctor

# Local development
tgm run                 # start locally (polling)
tgm docker up           # start via docker-compose
tgm docker logs -f

# Versioning and release
tgm version             # show version
tgm version bump minor  # increment version

# VPS deployment
tgm vps test --host 1.2.3.4 --user app --key ~/.ssh/id_ed25519
tgm deploy vps --image ghcr.io/ORG/BOT_IMAGE:1.1.0
```

---

## Current README Compatibility and Migration Plan

To preserve the current workflow during `tgm` implementation, it's necessary to:

- Provide wrappers: `tgm run|docker up|deploy vps` can call corresponding `manager.py`/`Makefile` commands within the repository until full migration;
- Agree on a unified configuration source: `.env` and `pyproject.toml`; avoid parameter duplication;
- Gradually migrate logic from `scripts/` and `manager.py` to `src/cli/*`, maintaining backward compatibility of commands and messages;
- Document changes and decisions in `DEVELOPMENT_LOG.md`.

---

## 🎯 MVP Brief Summary

### Already Implemented ✅

- Full-featured Telegram bot with admin system and monitoring
- Comprehensive CLI interface (`manager.py`) for all main operations
- Production-ready Docker infrastructure with health checks and auto-restart
- Automated development environment setup (VS Code/Cursor, linting, formatting)
- Modular architecture with clear separation of responsibilities

### Required for MVP ⚠️

1. **SSH client module** (`scripts/ssh_client.py`) - secure VPS connection
2. **Deployment module** (`scripts/deploy.py`) - automatic VPS deployment
3. **Extended versioning** (`scripts/version.py`) - commitizen integration
4. **Deploy command** in `manager.py` - `python manager.py deploy vps`

### Work Volume Estimation

- **SSH client**: ~2-3 days (with security and validation)
- **Deploy module**: ~3-4 days (with rollback and health checks)
- **Versioning**: ~1-2 days (commitizen integration)
- **CLI integration**: ~1 day (adding commands to manager.py)

**Total for MVP: ~7-10 development days**

---

## DX (Developer Experience) Requirements

- Predictable commands with consistent flags.
- Clear error messages and fixing recommendations.
- Operation idempotency (re-running is safe).
- Dry-run support (`--dry-run`) for dangerous operations (deploy/rollback).

---

## Minimal Implementation Requirements

- CLI with subcommands `init`, `doctor`, `run`, `docker`, `version`, `deploy vps`.
- `ssh_client` module with parameter validation and test connection.
- Docker integration (locally and on VPS) without provider-specific binding.
- Documentation: updated `README.md`, `REQUIREMENTS.md`, `DEVELOPMENT_LOG.md`, `.env.example`.
- Basic tests for CLI and SSH modules.
