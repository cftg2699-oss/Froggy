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

# ── Asegurar credencial ──
git config credential.helper 'store --file /home/ghost/.openclaw/.git-credentials' 2>/dev/null
export GIT_TERMINAL_PROMPT=0

echo "🐸 Froggy Logs - Sync ${TODAY}"
echo "═══════════════════════════════════"

# ── 1. Contar sesiones, mensajes y costos ──
echo ""
echo "📊 Procesando sesiones..."

total_sessions=0
total_user_msgs=0
total_froggy_msgs=0
total_cost=0

for f in "$SESSION_DIR"/*.jsonl; do
  [[ "$f" == *.trajectory.* ]] && continue
  msg_count=$(jq -s '[.[] | select(.type=="message")] | length' "$f" 2>/dev/null)
  user_c=$(jq -s '[.[] | select(.type=="message" and .message.role=="user")] | length' "$f" 2>/dev/null)
  froggy_c=$((msg_count - user_c))
  total_sessions=$((total_sessions + 1))
  total_user_msgs=$((total_user_msgs + user_c))
  total_froggy_msgs=$((total_froggy_msgs + froggy_c))
  session_cost=$(jq -s '[.[] | .message.usage.cost.total // 0] | add' "$f" 2>/dev/null)
  total_cost=$(echo "$total_cost + $session_cost" | bc 2>/dev/null || echo "0")
done

echo "   📊 $total_sessions sesiones | $total_user_msgs msgs usuario | $total_froggy_msgs respuestas"
echo "   💰 Costo total: \$$(printf '%.6f' $total_cost 2>/dev/null)"

# ── 3. Generar log diario Markdown ──
echo ""
echo "📝 Generando log diario..."

{
  echo "# 🐸 Log de Actividades — ${TODAY}"
  echo ""
  echo "## Resumen General"
  echo ""
  echo "| Métrica | Valor |"
  echo "|---------|-------|"
  echo "| **Sesiones activas** | $total_sessions |"
  echo "| **Mensajes de usuarios** | $total_user_msgs |"
  echo "| **Respuestas de Froggy** | $total_froggy_msgs |"
  echo "| **Total interacciones** | $((total_user_msgs + total_froggy_msgs)) |"
  echo "| **Costo operativo** | \$$(printf '%.6f' $total_cost 2>/dev/null) USD |"
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
    froggy_count=$(jq -s '[.[] | select(.type=="message" and .message.role=="assistant")] | length' "$f" 2>/dev/null)
    first_ts=$(jq -r 'select(.type=="message") | .timestamp[:16]' "$f" 2>/dev/null | head -1)
    last_ts=$(jq -r 'select(.type=="message") | .timestamp[:16]' "$f" 2>/dev/null | tail -1)
    session_cost=$(jq -s '[.[] | .message.usage.cost.total // 0] | add' "$f" 2>/dev/null)

    echo "### 💬 Sesión \`${session_id:0:12}...\`"
    echo ""
    echo "| | |"
    echo "|---|---|"
    echo "| **Inicio** | $first_ts |"
    echo "| **Fin** | $last_ts |"
    echo "| **👤 Usuario** | ${user_count} mensajes |"
    echo "| **🐸 Froggy** | ${froggy_count} respuestas |"
    echo "| **💰 Costo** | \$$(printf '%.6f' $session_cost 2>/dev/null) USD |"
    echo ""
    if [ -n "$first_msg" ]; then
      echo "> ${first_msg}"
      echo ""
    fi
    echo "[📄 Ver conversación completa](sessions/${session_id}.md)"
    echo ""
  done

  echo "---"
  echo "_🕒 Generado: $(date '+%Y-%m-%d %H:%M:%S %Z')_"
  echo "_🐸 Froggy · FraudEG_"
} > "$LOG_DIR/${TODAY}.md"

echo "   ✅ logs/${TODAY}.md"

# ── 4. Exportar conversaciones completas ──
echo ""
echo "📄 Exportando conversaciones completas..."

for f in "$SESSION_DIR"/*.jsonl; do
  [[ "$f" == *.trajectory.* ]] && continue
  session_id=$(basename "$f" .jsonl)

  # Extraer primeros mensajes para identificar usuario
  user_info=$(jq -r 'select(.type=="message" and .message.role=="user") | [.message.content[]? | select(.type=="text") | .text] | join(" ")' "$f" 2>/dev/null | head -3 | cut -c1-200)

  # Costo de la sesión
  session_cost=$(jq -s '[.[] | .message.usage.cost.total // 0] | add' "$f" 2>/dev/null)
  user_count=$(jq -s '[.[] | select(.type=="message" and .message.role=="user")] | length' "$f" 2>/dev/null)
  froggy_count=$(jq -s '[.[] | select(.type=="message" and .message.role=="assistant")] | length' "$f" 2>/dev/null)

  {
    echo "# 🐸 Conversación: \`${session_id:0:16}...\`"
    echo ""
    echo "**Usuario:** ${user_info:-Desconocido}"
    echo ""
    echo "**📊 Métricas de la sesión:**"
    echo ""
    echo "| Métrica | Valor |"
    echo "|---------|-------|"
    echo "| **👤 Mensajes usuario** | $user_count |"
    echo "| **🐸 Respuestas Froggy** | $froggy_count |"
    echo "| **💰 Costo** | \$$(printf '%.6f' $session_cost 2>/dev/null) USD |"
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

# ── 5. Commit & Push ──
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
