#!/bin/bash
# 🐸 Froggy Auto-Logs - Push automático al repositorio de founders
# Uso: bash scripts/push-logs.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_ID="main"
SESSION_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}/agents/$AGENT_ID/sessions"
TODAY=$(date +%Y-%m-%d)
LOG_DIR="$REPO_DIR/logs"
SESSION_LOG_DIR="$REPO_DIR/sessions"

cd "$REPO_DIR"

echo "🐸 Froggy Logs - Sync ${TODAY}"
echo "═══════════════════════════════════"

# ── 1. Contar sesiones y mensajes ──
total_sessions=0
total_user_msgs=0
total_froggy_msgs=0

for f in "$SESSION_DIR"/*.jsonl; do
  [[ "$f" == *.trajectory.* ]] && continue
  msg_count=$(jq -s '[.[] | select(.type=="message")] | length' "$f" 2>/dev/null)
  user_c=$(jq -s '[.[] | select(.type=="message" and .message.role=="user")] | length' "$f" 2>/dev/null)
  froggy_c=$((msg_count - user_c))
  total_sessions=$((total_sessions + 1))
  total_user_msgs=$((total_user_msgs + user_c))
  total_froggy_msgs=$((total_froggy_msgs + froggy_c))
done

echo "   📊 $total_sessions sesiones | $total_user_msgs msgs usuario | $total_froggy_msgs respuestas"

# ── 2. Generar log diario Markdown ──
echo ""
echo "📝 Generando log diario..."

{
  echo "# 🐸 Log de Actividades — ${TODAY}"
  echo ""
  echo "## Resumen"
  echo ""
  echo "- **Sesiones activas:** $total_sessions"
  echo "- **Mensajes de usuarios:** $total_user_msgs"
  echo "- **Respuestas de Froggy:** $total_froggy_msgs"
  echo "- **Total interacciones:** $((total_user_msgs + total_froggy_msgs))"
  echo ""
  echo "---"
  echo ""
  echo "## Conversaciones del día"
  echo ""

  for f in "$SESSION_DIR"/*.jsonl; do
    [[ "$f" == *.trajectory.* ]] && continue
    session_id=$(basename "$f" .jsonl)
    first_msg=$(jq -r 'select(.type=="message" and .message.role=="user") | [.message.content[]? | select(.type=="text") | .text] | join(" ")' "$f" 2>/dev/null | head -1 | cut -c1-120)
    user_count=$(jq -s '[.[] | select(.type=="message" and .message.role=="user")] | length' "$f" 2>/dev/null)
    first_ts=$(jq -r 'select(.type=="message") | .timestamp[:16]' "$f" 2>/dev/null | head -1)
    last_ts=$(jq -r 'select(.type=="message") | .timestamp[:16]' "$f" 2>/dev/null | tail -1)

    echo "### 💬 Sesión \`${session_id:0:12}...\`"
    echo ""
    echo "| | |"
    echo "|---|---|"
    echo "| **Inicio** | $first_ts |"
    echo "| **Fin** | $last_ts |"
    echo "| **Mensajes** | $user_count del usuario |"
    echo ""
    if [ -n "$first_msg" ]; then
      echo "> ${first_msg}"
      echo ""
    fi
    echo "[📄 Ver completa](sessions/${session_id}.md)"
    echo ""
  done

  echo "---"
  echo "_🕒 Generado: $(date '+%Y-%m-%d %H:%M:%S %Z')_"
  echo "_🐸 Froggy · FraudEG_"
} > "$LOG_DIR/${TODAY}.md"

echo "   ✅ logs/${TODAY}.md"

# ── 3. Exportar conversaciones completas ──
echo ""
echo "📄 Exportando conversaciones completas..."

for f in "$SESSION_DIR"/*.jsonl; do
  [[ "$f" == *.trajectory.* ]] && continue
  session_id=$(basename "$f" .jsonl)

  # Extract user identifier from first messages for context
  user_info=$(jq -r 'select(.type=="message" and .message.role=="user") | [.message.content[]? | select(.type=="text") | .text] | join(" ")' "$f" 2>/dev/null | head -3 | cut -c1-200)

  {
    echo "# 🐸 Conversación: \`${session_id:0:16}...\`"
    echo ""
    echo "**Usuario:** ${user_info:-Desconocido}"
    echo ""
    echo "---"
    echo ""

    jq -r 'select(.type=="message") |
      "### " + (.timestamp[:19] | sub("T"; " ")) + "\n\n" +
      (if .message.role == "user" then "**👤 Usuario:**" else "**🐸 Froggy:**" end) + "\n\n" +
      ([.message.content[]? | select(.type=="text") | .text] | join("\n")) + "\n\n---\n"' "$f" 2>/dev/null

    echo ""
    echo "_Exportado: $(date '+%Y-%m-%d %H:%M:%S')_"
  } > "$SESSION_LOG_DIR/${session_id}.md"

  echo "   ✅ sessions/${session_id}.md"
done

# ── 4. Commit & Push ──
echo ""
echo "⬆️ Subiendo a GitHub..."

git add -A
if git diff --cached --quiet; then
  echo "   ℹ️  Sin cambios nuevos"
else
  git commit -m "📦 Logs ${TODAY} — $(date '+%H:%M')"
  if git push origin main 2>/dev/null || git push origin master 2>/dev/null; then
    echo "   ✅ Push exitoso"
  else
    echo "   ❌ Error en push"
  fi
fi

echo ""
echo "═══════════════════════════════════"
echo "✅ Sync completado — ${TODAY}"
