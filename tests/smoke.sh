#!/usr/bin/env bash
# Şablon betiklerinin temel davranışını doğrular. Ağ gerektirmez; sahte komutlar kullanır.
# Çalıştır: bash tests/smoke.sh

set -uo pipefail

KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BETIK="$KOK/templates/scripts/cloud-session-start.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gecti=0
kaldi=0
kontrol() { # kontrol <açıklama> <komut...>
  if "${@:2}"; then
    echo "ok   - $1"
    gecti=$((gecti + 1))
  else
    echo "HATA - $1"
    kaldi=$((kaldi + 1))
  fi
}
icerir() { grep -qF -- "$2" <<<"$1"; }
jq_dogru() { jq -e "$@" >/dev/null; }

# Sahte paket yöneticileri: çağrıldıklarını sayaca yazar
mkdir -p "$TMP/bin"
for arac in go npm; do
  cat >"$TMP/bin/$arac" <<'EOF'
#!/bin/sh
[ -n "${SAHTE_HATA:-}" ] && { echo "sahte hata: baglanti reddedildi" >&2; exit 1; }
echo "$(basename "$0") $*" >>"$SAYAC"
[ "$(basename "$0")" = npm ] && mkdir -p node_modules
exit 0
EOF
  chmod +x "$TMP/bin/$arac"
done

bulutta() { # bulutta <proje> [ek ortam değişkenleri...]
  local proje="$1"
  shift
  env PATH="$TMP/bin:$PATH" SAYAC="$TMP/sayac" HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" \
    CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$proje" CLAUDE_ENV_FILE="$TMP/envfile" \
    SESSION_START_SKIP="" SESSION_START_SERVICES="" "$@" bash "$BETIK"
}
sayac() { if [ -f "$TMP/sayac" ]; then wc -l <"$TMP/sayac" | tr -d ' '; else echo 0; fi; }

# 1) Yerelde hiçbir şey yapmaz
mkdir -p "$TMP/bos"
cikti="$(cd "$TMP/bos" && env -u CLAUDE_CODE_REMOTE bash "$BETIK")"
kontrol "yerelde sessizce çıkar" test -z "$cikti"

# 2) Bağımlılık dosyası olmayan projede özet verir
cikti="$(bulutta "$TMP/bos")"
kontrol "boş projede 'yapılacak iş yok' der" icerir "$cikti" "yapılacak iş yok"

# 3) Hash ile atlama (Go)
mkdir -p "$TMP/go"
echo 'module ornek' >"$TMP/go/go.mod"
cikti="$(bulutta "$TMP/go")"
kontrol "ilk çalıştırmada kurar" icerir "$cikti" "go: kuruldu"
cikti="$(bulutta "$TMP/go")"
kontrol "değişiklik yoksa atlar" icerir "$cikti" "go: güncel, atlandı"
echo '// degisti' >>"$TMP/go/go.mod"
cikti="$(bulutta "$TMP/go")"
kontrol "go.mod değişince yeniden kurar" icerir "$cikti" "go: kuruldu"
kontrol "kurulum komutu tam 2 kez çalıştı" test "$(sayac)" = 2

kontrol "göreli yolla çağrılınca da atlar" icerir "$(cd "$KOK" && BETIK=templates/scripts/cloud-session-start.sh bulutta "$TMP/go")" "go: güncel, atlandı"

# 4) SESSION_START_SKIP
cikti="$(bulutta "$TMP/go" SESSION_START_SKIP="go")"
kontrol "SESSION_START_SKIP adımı atlar" icerir "$cikti" "go: atlandı (SESSION_START_SKIP)"

# 5) Hata raporlanır, betik yine 0 ile çıkar
cikti="$(bulutta "$TMP/go" SESSION_START_FORCE=1 SAHTE_HATA=1)"
kod=$?
kontrol "başarısız adım raporlanır" icerir "$cikti" "go: BAŞARISIZ"
kontrol "hata logunun sonu Claude'a gösterilir" icerir "$cikti" "baglanti reddedildi"
kontrol "hata olsa da çıkış kodu 0" test "$kod" = 0
cikti="$(bulutta "$TMP/go")"
kontrol "başarısız kurulumdan sonra yeniden dener" icerir "$cikti" "go: kuruldu"

# 6) Node: node_modules silinirse hash aynı olsa da yeniden kurar; PATH CLAUDE_ENV_FILE'a yazılır
mkdir -p "$TMP/node"
echo '{"name":"ornek"}' >"$TMP/node/package.json"
bulutta "$TMP/node" >/dev/null
kontrol "CLAUDE_ENV_FILE'a node_modules/.bin eklenir" grep -qF "$TMP/node/node_modules/.bin" "$TMP/envfile"
rm -rf "$TMP/node/node_modules"
cikti="$(bulutta "$TMP/node")"
kontrol "node_modules silinince yeniden kurar" icerir "$cikti" "node: kuruldu"

# 7) projeye-ekle.sh
mkdir -p "$TMP/proje/.claude"
git -C "$TMP/proje" init -q
echo '{"permissions":{"allow":["Bash(npm test)"]}}' >"$TMP/proje/.claude/settings.json"
bash "$KOK/scripts/projeye-ekle.sh" "$TMP/proje" >/dev/null
kontrol "mevcut settings.json korunur ve hook eklenir" \
  jq_dogru '.permissions.allow[0] == "Bash(npm test)" and (.hooks.SessionStart | length) == 1' "$TMP/proje/.claude/settings.json"
bash "$KOK/scripts/projeye-ekle.sh" "$TMP/proje" >/dev/null
kontrol "ikinci çalıştırmada hook çoğaltılmaz" \
  jq_dogru '(.hooks.SessionStart | length) == 1' "$TMP/proje/.claude/settings.json"
kontrol "başlangıç betiği çalıştırılabilir olarak eklenir" test -x "$TMP/proje/scripts/cloud-session-start.sh"
kontrol "CLAUDE.md eklenir" test -f "$TMP/proje/CLAUDE.md"
echo "# benim" >"$TMP/proje2.md"
mkdir -p "$TMP/proje2"
cp "$TMP/proje2.md" "$TMP/proje2/CLAUDE.md"
bash "$KOK/scripts/projeye-ekle.sh" "$TMP/proje2" >/dev/null
kontrol "var olan CLAUDE.md'nin üzerine yazmaz" cmp -s "$TMP/proje2.md" "$TMP/proje2/CLAUDE.md"

# 8) Şablon JSON geçerli
kontrol "templates/.claude/settings.json geçerli JSON" jq empty "$KOK/templates/.claude/settings.json"

echo
echo "$gecti geçti, $kaldi kaldı"
[ "$kaldi" -eq 0 ]
