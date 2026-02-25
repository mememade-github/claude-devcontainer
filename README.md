# Claude Code DevContainer

Claude Code + 14 Agent System이 포함된 격리 개발 환경 템플릿.

**필요 조건**: [Docker Desktop](https://www.docker.com/products/docker-desktop/)

---

## 시작하기

### Step 1: 클론 & 빌드

```bash
git clone https://github.com/mememade-github/claude-code-devcontainer.git my-project
cd my-project/.devcontainer
docker compose up -d --build    # 첫 빌드 ~3-5분
```

### Step 2: 컨테이너 진입

```bash
docker exec -it claude-code-dev bash
```

### Step 3: Claude Code 실행

```bash
claude --dangerously-skip-permissions
```

### Step 4: 프로젝트 초기 설정

Claude 프롬프트에 아래 전체를 붙여넣기:

```
프로젝트 초기 설정을 수행해 주세요.

## 수집할 정보 (대화형으로 질문)
- 프로젝트명, 설명, GitHub URL
- 언어/프레임워크 (예: Python+FastAPI, TypeScript+Next.js, Go+Gin)
- 필요한 서비스 (PostgreSQL, Redis, OpenSearch 등)
- 포트 매핑 (기본: APP=3000, API=8080, DB=5432, EXTRA=6379)
- 서버 정보 (있으면)
- 테스트 프레임워크, CI/CD, 커밋 메시지 언어

## 수행할 작업
1. 프로젝트에 필요한 언어/도구 설치 (apt, nvm, pip, cargo 등)
2. .serena/project.yml — languages 배열에 프로젝트 언어 추가
3. CLAUDE.md — Identity 섹션 업데이트
4. PROJECT.md — 프로젝트에 맞게 재작성
5. REFERENCE.md — 프로젝트별 명령어 업데이트
6. .devcontainer/.env — 포트, 타임존, Node 버전 설정
7. .devcontainer/devcontainer.json — forwardPorts 동기화
8. .claude/rules/project/ — 프로젝트 코딩 규칙 생성

## 검증
- bash .devcontainer/verify-template.sh
- bash .claude/hooks/test-hooks.sh

## 주의
- .claude/settings.json, Dockerfile, 에이전트 frontmatter는 수정 금지

질문부터 시작해 주세요.
```

### Step 5: 저장

```bash
git add -A && git commit -m "chore: initialize project"
```

---

## VS Code로 사용하기 (선택)

CLI 대신 VS Code Dev Containers를 사용할 수 있습니다.

**추가 필요**: [VS Code](https://code.visualstudio.com/) + [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

1. VS Code로 프로젝트 폴더 열기
2. 좌측 하단 `><` → **Reopen in Container**
3. 터미널에서 `claude` 실행 → Step 4 동일

> VS Code 사용 시 `--dangerously-skip-permissions` 불필요 (터미널에서 권한 프롬프트 가능).

---

## 포함 사항

| 구성 | 수량 | 내용 |
|------|------|------|
| Agents | 14 | code-reviewer, security-reviewer, debugger, planner, architect 등 |
| Hooks | 13 | 세션 시작, 파괴적 명령 차단, 코드리뷰 자동 트리거, 커밋 전 검증 등 |
| Skills | 12 | /commit, /pr, /verify, /status, /deploy, /learn 등 |
| MCP | 2 | Context7 (문서 검색), Serena (코드 인텔리전스) |
| Tools | 20+ | ripgrep, fd, fzf, jq, tmux, docker CLI, gh 등 |

## 포트 변경

`.devcontainer/.env`의 `PORT_*` 값 변경 후 `.devcontainer/devcontainer.json`의 `forwardPorts`도 동일하게 수정. 이후 컨테이너 재빌드.

## Troubleshooting

| 문제 | 해결 |
|------|------|
| 빌드 실패 | `docker compose build --no-cache` |
| Claude 재인증 | `docker volume ls \| grep claude-config` 확인 |
| MCP 연결 실패 | `rm ~/.claude.json && /usr/local/bin/setup-env.sh` |
| 포트 충돌 | `.env` + `devcontainer.json` 포트 변경 후 재빌드 |
