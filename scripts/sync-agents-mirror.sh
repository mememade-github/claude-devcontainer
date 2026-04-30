#!/bin/bash
# =============================================================================
# sync-agents-mirror.sh — .claude/ → .agents/ 단방향 미러
# =============================================================================
# Claude Code 자산(`.claude/`)을 Codex CLI 호환 형식(`.agents/`)으로 동기화.
# Ground truth는 `.claude/`. `.agents/`는 자동 생성된 미러이므로 직접 수정 금지.
#
# 사용:
#   bash scripts/sync-agents-mirror.sh         # 미러 갱신
#   bash scripts/sync-agents-mirror.sh --dry   # 변경 사항만 표시
#
# 동기화 매핑:
#   .claude/rules/        → .agents/rules/        (디렉토리 단순 복사)
#   .claude/skills/       → .agents/skills/       (디렉토리 단순 복사)
#   .claude/security/     → .agents/security/     (디렉토리 단순 복사)
#   .claude/agents/<X>.md → .agents/skills/<X>/SKILL.md  (단일 파일 → 스킬 디렉토리)
#
# 동기화 제외:
#   .claude/hooks/    — Codex는 .codex/hooks/ 별도 관리
#   .claude/settings.json — Claude 전용
#
# 알려진 vendor 손실 (Codex CLI 미지원 frontmatter 필드):
#   tools / model / color — 무시됨. agents → skills 변환 시 본문은 그대로 유지.
#
# Preserve-extras 정책:
#   각 sub-project가 .agents/ 측에 자체 추가 파일을 보유할 수 있음 (예: <internal-rag>의
#   vendor-limitations.md, refine/wiki-integration.md). cp -a로 overlay 방식 적용 —
#   ground-truth 파일은 갱신, dest-only 파일은 보존. 손실 방지.
# =============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$PROJECT_ROOT/.claude"
DST="$PROJECT_ROOT/.agents"
DRY_RUN=0

[ "${1:-}" = "--dry" ] && DRY_RUN=1

if [ ! -d "$SRC" ]; then
    echo "ERROR: $SRC not found. .claude/ ground truth required." >&2
    exit 1
fi

mkdir -p "$DST"

CHANGED=0
for SUB in rules skills security; do
    SRC_SUB="$SRC/$SUB"
    DST_SUB="$DST/$SUB"
    [ -d "$SRC_SUB" ] || continue

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ ! -d "$DST_SUB" ]; then
            echo "[DRY] would create: $SUB/"
            CHANGED=$((CHANGED + 1))
        else
            # Source-side files differing from dest (preserve-extras: ignore dest-only)
            DIFF=$(diff -rq "$SRC_SUB" "$DST_SUB" 2>/dev/null | grep -v "^Only in $DST_SUB" | wc -l)
            [ "$DIFF" -gt 0 ] && echo "[DRY] would update: $SUB/ ($DIFF item(s))" && CHANGED=$((CHANGED + 1))
        fi
    else
        # Preserve-extras: overlay source onto dest. dest-only files retained.
        mkdir -p "$DST_SUB"
        cp -a "$SRC_SUB"/. "$DST_SUB"/
        echo "[SYNC] $SUB/ (preserve-extras)"
        CHANGED=$((CHANGED + 1))
    fi
done

# agents → skills 변환 (단일 파일 → 스킬 디렉토리)
if [ -d "$SRC/agents" ]; then
    for AGENT in "$SRC/agents"/*.md; do
        [ -f "$AGENT" ] || continue
        NAME=$(basename "$AGENT" .md)
        # 메타/스키마 파일 제외
        case "$NAME" in _*) continue ;; esac
        DST_SKILL_DIR="$DST/skills/$NAME"
        DST_SKILL="$DST_SKILL_DIR/SKILL.md"
        if [ "$DRY_RUN" -eq 1 ]; then
            if [ ! -f "$DST_SKILL" ] || ! cmp -s "$AGENT" "$DST_SKILL"; then
                echo "[DRY] would convert: agents/${NAME}.md → skills/${NAME}/SKILL.md"
                CHANGED=$((CHANGED + 1))
            fi
        else
            mkdir -p "$DST_SKILL_DIR"
            cp "$AGENT" "$DST_SKILL"
            echo "[CONVERT] agents/${NAME}.md → skills/${NAME}/SKILL.md"
            CHANGED=$((CHANGED + 1))
        fi
    done
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "Dry run complete. $CHANGED change(s) detected."
else
    echo ""
    echo "Sync complete. $CHANGED change(s) applied."
    echo "Note: .agents/ is a generated mirror. Edit .claude/ as ground truth."
fi
