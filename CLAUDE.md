# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Installation and Setup
```bash
# Install dependencies for local development
./install.sh                    # Install Python dependencies (macOS/Linux)
./install.bat                   # Install Python dependencies (Windows)

# Install frontend dependencies
cd frontend/agentic-seek-front
npm install
```

### Running the Application
```bash
# Start all services (Docker required)
./start_services.sh full        # Start frontend, backend, searxng, redis
./start_services.sh             # Start only frontend and search services
./start_services_podman.sh full # Use Podman instead of Docker

# CLI mode (after installing dependencies)
uv run cli.py                   # Run in CLI mode
```

### Testing
```bash
# Comprehensive API testing
python test_api_comprehensive.py

# Individual test files
python test_browser_fix.py
python test_configurable_url.py
python test_language_setting.py
python test_offline_mode.py

# Frontend testing
cd frontend/agentic-seek-front
npm test                        # Run React tests
npm run build                   # Build frontend
```

### Development Tools
```bash
# Log monitoring
./show_logs.sh                  # View all logs
./show_logs.sh -f backend       # Follow backend logs
./show_logs.sh -l               # List available log files
./show_logs.py --list           # Python version with more features

# Provider configuration
./switch_provider.sh            # Interactive LLM provider switcher

# Health checks
./health_check_podman.sh        # Check Podman service health
./full_verification_test.sh     # Full system verification
```

### Docker Operations
```bash
docker compose up -d             # Start services in background
docker compose down              # Stop all services
docker compose logs -f backend   # Follow backend logs
docker compose exec backend bash # Enter backend container
```

## Architecture Overview

### Core Components

**Multi-Agent System**: AgenticSeek uses a router-based architecture with specialized agents:
- `sources/router.py` - Intelligent agent selection and task routing
- `sources/agents/` - Specialized agents (coder, browser, file, casual, planner, mcp)
- `sources/tools/` - Executable tools for various programming languages and utilities

**LLM Provider Abstraction**: `sources/llm_provider.py` provides unified interface for multiple LLM providers:
- Local: Ollama, LM Studio, custom OpenAI-compatible servers
- Cloud: OpenAI, Anthropic, Google, DeepSeek, TogetherAI
- Private: Self-hosted server via `llm_server/`

**API Layer**: FastAPI-based REST API (`api.py`) serving:
- Frontend communication on port 7777
- WebSocket support for streaming responses
- Async task processing with Celery

**Frontend**: React application (`frontend/agentic-seek-front/`) with:
- Real-time chat interface
- Markdown rendering
- Theme support (light/dark)

### Key Directories

- `sources/agents/` - Agent implementations with different specializations
- `sources/tools/` - Language interpreters and utility tools
- `prompts/` - Agent system prompts (base/ and jarvis/ variants)
- `searxng/` - Private search engine configuration
- `llm_server/` - Standalone LLM server for remote deployment
- `tests/` - Unit tests for various components

### Configuration

**Main Config**: `config.ini` contains core settings:
- LLM provider selection and model configuration
- Agent personality settings (Jarvis mode)
- Browser configuration (headless/stealth mode)
- Work directory for file operations

**Environment**: `.env` contains runtime configuration:
- Service URLs (SearxNG, Redis)
- API keys for cloud providers
- Port configurations for local services

## Development Workflow

### Adding New Agents
1. Create agent class in `sources/agents/` inheriting from `Agent`
2. Add agent to router voting system in `sources/router.py`
3. Create prompt template in `prompts/base/` (and optionally `prompts/jarvis/`)
4. Add agent type to schemas in `sources/schemas.py`

### Adding New Tools
1. Create tool class in `sources/tools/` inheriting from `Tools`
2. Implement required abstract methods: `execute()`, `execution_failure_check()`, `interpreter_feedback()`
3. Register tool with appropriate agents
4. Add safety checks in `sources/tools/safety.py`

### Testing Strategy
- Unit tests for individual components in `tests/`
- Integration tests via `test_*.py` scripts
- Comprehensive API testing with `test_api_comprehensive.py`
- Browser automation testing with Selenium

## Common Issues

**Browser Automation**: ChromeDriver version must match Chrome browser version. Use chromedriver-autoinstaller or manual installation from Chrome for Testing.

**LLM Provider Configuration**: Ensure `provider_server_address` includes protocol prefix (e.g., `http://127.0.0.1:11434` for LM Studio).

**Docker Volumes**: Work directory (`WORK_DIR`) is mounted into containers and must not exceed 2GB for Docker compatibility.

**Memory Usage**: Large language models require significant RAM/VRAM. Monitor resource usage during development.

## Service Ports

- Frontend: 3000
- Backend API: 7777
- SearxNG Search: 8080
- Redis: 6379
- Ollama: 11434 (default)
- LM Studio: 1234 (default)