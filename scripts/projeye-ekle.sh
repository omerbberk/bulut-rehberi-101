#!/usr/bin/env bash
# Rehberdeki şablonları bir projeye ekler. Var olan dosyaların üzerine yazmaz.
#
# Kullanım: bash scripts/projeye-ekle.sh /proje/dizini
#
# Ekledikleri:
#   scripts/cloud-session-start.sh   bulutta bağımlılıkları kuran betik
#   .claude/settings.json            SessionStart hook'u (dosya varsa jq ile birleştirilir)
#   CLAUDE.md                        yoksa şablon olarak

set -euo pipefail

REHBER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$REHBER/templates"
# shellcheck disable=SC2016 # $CLAUDE_PROJECT_DIR'ı hook çalışırken Claude Code genişletir
HOOK_CMD='bash "$CLAUDE_PROJECT_DIR"/scripts/cloud-session-start.sh'

if [ "$#" -ne 1 ]; then
  echo "Kullanım: $0 <proje-dizini>" >&2
  exit 64
fi
if [ ! -d "$1" ]; then
  echo "Dizin bulunamadı: $1" >&2
  exit 66
fi
HEDEF="$(cd "$1" && pwd)"

echo "Hedef: $HEDEF"
if ! git -C "$HEDEF" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "  UYARI: bu bir git deposu değil. Bulut oturumları yalnızca commit edilip push edilen dosyaları görür."
fi

# kopyala <kaynak> <hedef>: hedef yoksa kopyalar; eklendiyse 0, atlandıysa 1 döner
kopyala() {
  if [ -e "$2" ]; then
    echo "  atlandı (zaten var): ${2#"$HEDEF"/}"
    return 1
  fi
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  echo "  eklendi: ${2#"$HEDEF"/}"
}

# 1) Başlangıç betiği
if kopyala "$T/scripts/cloud-session-start.sh" "$HEDEF/scripts/cloud-session-start.sh"; then
  chmod +x "$HEDEF/scripts/cloud-session-start.sh"
fi

# 2) SessionStart hook'u
AYAR="$HEDEF/.claude/settings.json"
if [ ! -e "$AYAR" ]; then
  kopyala "$T/.claude/settings.json" "$AYAR" || true
elif ! command -v jq >/dev/null 2>&1; then
  echo "  UYARI: .claude/settings.json var ama jq kurulu değil. Hook'u elle ekle: templates/.claude/settings.json"
elif ! jq empty "$AYAR" 2>/dev/null; then
  echo "  UYARI: .claude/settings.json geçerli JSON değil, dokunulmadı. Hook'u elle ekle: templates/.claude/settings.json"
elif jq -e --arg c "$HOOK_CMD" '[.hooks.SessionStart[]?.hooks[]?.command] | index($c)' "$AYAR" >/dev/null; then
  echo "  atlandı (hook zaten tanımlı): .claude/settings.json"
else
  yeni="$(jq --slurpfile t "$T/.claude/settings.json" \
    '.hooks.SessionStart = ((.hooks.SessionStart // []) + $t[0].hooks.SessionStart)' "$AYAR")"
  # Dosya izinlerini korumak için üzerine yaz (mv yerine)
  printf '%s\n' "$yeni" >"$AYAR"
  echo "  güncellendi: .claude/settings.json (SessionStart hook'u eklendi)"
fi

# 3) CLAUDE.md
if ! kopyala "$T/CLAUDE.md" "$HEDEF/CLAUDE.md"; then
  echo "    → templates/CLAUDE.md içindeki \"Bulut oturumları\" bölümünü kendi CLAUDE.md'ne eklemeyi düşün."
fi

cat <<'EOF'

Sonraki adımlar:
  1. CLAUDE.md içindeki köşeli parantezli yerleri projene göre doldur.
  2. Commit edip push et (bulut oturumu GitHub'daki dalı klonlar):
       git add scripts/cloud-session-start.sh .claude/settings.json CLAUDE.md
       git commit -m "chore: Claude Code bulut oturumu kurulumu"
       git push
  3. Yeni bir bulut oturumu aç; ilk mesajda "[cloud-session-start]" özetini Claude görecek.
EOF
