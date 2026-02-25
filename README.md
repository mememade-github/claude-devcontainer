# Claude Code DevContainer

모든 개발 프로젝트의 시작 템플릿.
Claude Code + Agent System이 포함된 격리된 개발 환경.

---

## 필요 조건

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [VS Code](https://code.visualstudio.com/) + [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

---

## 시작하기

### 1. 환경 설정

```bash
cp .devcontainer/.env.example .devcontainer/.env
```

`.devcontainer/.env`을 열어 프로젝트에 맞게 수정:

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `COMPOSE_PROJECT_NAME` | `claude-code` | Docker 프로젝트명 (인스턴스별 고유) |
| `CONTAINER_NAME` | `claude-code-dev` | 컨테이너 이름 |
| `PORT_APP` | `3000` | 앱/dev server 포트 |
| `PORT_API` | `8080` | API 서버 포트 |
| `PORT_DB` | `5432` | 데이터베이스 포트 |
| `PORT_EXTRA` | `6379` | 추가 포트 (Redis 등) |
| `PROJECT_NODE_VERSION` | *(비어있음)* | 프로젝트 Node.js 버전 |

### 2. 컨테이너 열기

1. VS Code로 이 폴더 열기
2. 좌측 하단 `><` → **Reopen in Container**
3. 첫 빌드: ~3-5분 소요

### 3. Claude Code 시작

```bash
claude
```

---

## 포트 관리

포트는 `.devcontainer/.env`에서 관리합니다.

**포트 변경 시:**
1. `.devcontainer/.env`의 `PORT_*` 값 변경
2. `.devcontainer/devcontainer.json`의 `forwardPorts` 배열도 같은 값으로 수정
3. Rebuild Container

**다중 인스턴스 (포트 충돌 방지):**
```bash
cp .devcontainer/.env .devcontainer/.env.project-b
# .env.project-b 수정:
#   COMPOSE_PROJECT_NAME=my-project-b
#   CONTAINER_NAME=my-project-b-dev
#   PORT_APP=3001
#   PORT_API=8081
docker compose -f .devcontainer/docker-compose.yml --env-file .devcontainer/.env.project-b up -d
```

**사용하지 않는 포트:**
`docker-compose.yml`의 해당 `ports` 줄을 주석 처리하세요.

---

## Node.js 버전 관리

Claude Code는 Node 20으로 동작하며, 프로젝트 Node와 격리되어 있습니다.

**프로젝트에 다른 Node 버전 필요 시:**

방법 A — `.nvmrc` (권장):
```bash
echo "18" > .nvmrc
# 터미널 재시작 → 자동 활성화
```

방법 B — `.env`에서 설정:
```
PROJECT_NODE_VERSION=18
```
→ Rebuild Container

---

## 언어/도구 설치

베이스 템플릿에는 언어가 포함되지 않습니다. 필요한 것을 직접 설치하세요.

```bash
# Python
sudo apt update && sudo apt install -y python3 python3-pip python3-venv

# Go
sudo apt install -y golang

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# uv (Python 패키지 관리자)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

영구 설치가 필요하면 `Dockerfile`에 추가 후 Rebuild.

---

## Agent System 구성

### 기동 후 자동 동작

컨테이너 시작 → `claude` 실행 시 Agent System이 자동 활성화됩니다:

- **SessionStart hook**: git 상태, WIP 태스크, Known Issues 보고
- **코드 수정 후**: code-reviewer 자동 트리거
- **커밋 전**: pre-commit-gate (검증 통과 필수)
- **세션 종료 시**: agent-evolver (에이전트 학습)

### 프로젝트 특화 설정

```
.claude/
├── rules/project/     ← 프로젝트 규칙 추가 (*.md 파일)
├── agents/            ← 에이전트 수정/추가
├── skills/            ← /command 추가
└── agent-memory/      ← 에이전트별 학습 메모리
```

**프로젝트 규칙 추가 예시** (`.claude/rules/project/my-rules.md`):
```markdown
# My Project Rules
- API 엔드포인트에 OpenAPI docstring 필수
- 데이터베이스 호출은 항상 async/await 사용
- 테스트 커버리지 80% 이상 유지
```

### 주요 에이전트

| 에이전트 | 동작 시점 | 기능 |
|---------|----------|------|
| code-reviewer | 코드 수정 후 | 버그, 스타일, 보안 리뷰 |
| planner | 복잡한 작업 요청 시 | 구현 계획 수립 |
| debugger | 에러 발생 시 | 근본 원인 분석 |
| wip-manager | 멀티세션 작업 | 세션간 진행 상황 추적 |

전체 14개 에이전트 목록: `REFERENCE.md` 참조

---

## Troubleshooting

| 문제 | 해결 |
|------|------|
| 컨테이너 빌드 실패 | `docker compose -f .devcontainer/docker-compose.yml build --no-cache` |
| Claude 재인증 요청 | `~/.claude` named volume 확인: `docker volume ls \| grep claude-config` |
| 잘못된 Node 버전 | `nvm use` 또는 `.nvmrc` 파일 생성 |
| 포트 충돌 | `.env`에서 `PORT_*` 변경 + `devcontainer.json` forwardPorts 수정 |
| MCP 연결 실패 | `rm ~/.claude.json && /usr/local/bin/setup-env.sh` |

---

## Variants

| 템플릿 | 용도 |
|--------|------|
| `claude-code-devcontainer` | **이 템플릿** — 범용 베이스 |
| `claude-code-devcontainer-data` | Jupyter + Data Science (Python, pandas, matplotlib 등) |
