#!/usr/bin/env bash
# Bulut doktoru: Claude Code bulut oturumunun röntgenini çeker.
#
# Kullanım: bir bulut oturumunda Claude'a şunu söyle:
#   "bash scripts/bulut-doktoru.sh çalıştır ve sonucu özetle"
# İstersen proje dizinini argüman olarak ver: bash scripts/bulut-doktoru.sh /home/user/projem
#
# Gizli bilgi yazdırmaz: token'ları ve ortam değişkeni değerlerini göstermez
# (yalnızca zaman aşımı ayarları gibi gizli olmayan birkaç değer hariç).

set -uo pipefail
# Türkçe karakterlerde hizalama için karakter (bayt değil) sayımı
export LC_ALL=C.UTF-8

PROJE="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
oneriler=()

baslik() { printf '\n== %s ==\n' "$1"; }
satir() { printf '  %s%*s %s\n' "$1" $((24 - ${#1})) '' "$2"; }
var_mi() { command -v "$1" >/dev/null 2>&1; }
oner() { oneriler+=("$1"); }

# --- Oturum --------------------------------------------------------------
baslik "Oturum"
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  satir "Bulut oturumu" "evet"
  if [ -n "${CLAUDE_CODE_REMOTE_SESSION_ID:-}" ]; then
    satir "Oturum bağlantısı" "https://claude.ai/code/${CLAUDE_CODE_REMOTE_SESSION_ID/#cse_/session_}"
  fi
else
  satir "Bulut oturumu" "hayır (CLAUDE_CODE_REMOTE=true değil); sonuçlar bu makineyi anlatır"
fi
satir "Proje dizini" "$PROJE"

# --- Sistem --------------------------------------------------------------
baslik "Sistem"
# shellcheck source=/dev/null
os="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-}")"
satir "İşletim sistemi" "${os:-$(uname -s)}"
satir "Mimari / çekirdek" "$(uname -m) / $(uname -r)"
satir "CPU" "$(nproc 2>/dev/null || echo '?') çekirdek"
if var_mi free; then
  satir "Bellek" "$(free -h | awk '/^Mem:/ {print $2 " toplam, " $7 " kullanılabilir"}')"
fi
if df_satir="$(df -Pk / 2>/dev/null | awk 'NR==2')"; then
  bos_kb="$(awk '{print $4}' <<<"$df_satir")"
  satir "Disk (kullanılabilir)" "$((bos_kb / 1024 / 1024)) GB  (not: disk oturum başına bir kotadır, 'Avail' değerine bak)"
  if [ "$bos_kb" -lt $((3 * 1024 * 1024)) ]; then
    oner "Disk kotası azalmış (<3 GB). Derleme çıktılarını ve önbellekleri sil (ör. docker system prune -f, cargo clean); işi push edip yeni oturum açmak da bir seçenek."
  fi
fi
if [ -d "$PROJE" ]; then
  for d in node_modules .venv target build dist .gradle vendor; do
    if [ -d "$PROJE/$d" ]; then
      satir "  $d" "$(timeout 10 du -sh "$PROJE/$d" 2>/dev/null | cut -f1 || echo '?')"
    fi
  done
fi

# --- Ağ ------------------------------------------------------------------
baslik "Ağ"
if [ -n "${HTTPS_PROXY:-}" ]; then
  satir "Çıkış proxy'si" "var (dış trafik ağ politikasından geçiyor)"
  # Önce proxy'nin son reddettiklerini oku. example.com bu betiğin kendi denemesi, listeden çıkarılır.
  durum="$(curl -sS -m 5 "$HTTPS_PROXY/__agentproxy/status" 2>/dev/null || true)"
  if [ -n "$durum" ] && var_mi jq; then
    engellenen="$(jq -r '[.recentRelayFailures[]?.host // empty | sub(":[0-9]+$"; "") | select(. != "example.com")] | unique | join(", ")' <<<"$durum" 2>/dev/null || true)"
    if [ -n "$engellenen" ]; then
      satir "Son engellenenler" "$engellenen"
      oner "Engellenen alan adları gerçekten gerekiyorsa: ortamı düzenle, Network access → Custom, bu alan adlarını ekle ('default list of common package managers' işaretli kalsın): $engellenen"
    else
      satir "Son engellenenler" "yok"
    fi
  fi
else
  satir "Çıkış proxy'si" "yok"
fi

dene() { # dene <etiket> <url>
  local kod
  kod="$(curl -sS -o /dev/null -m 6 -w '%{http_code}' "$2" 2>/dev/null)" || true
  if [ -z "$kod" ] || [ "$kod" = "000" ]; then
    satir "$1" "ERİŞİLEMİYOR"
    return 1
  fi
  satir "$1" "yanıt veriyor (HTTP $kod)"
}
dene "npm kayıt defteri" "https://registry.npmjs.org/" || true
dene "PyPI" "https://pypi.org/simple/" || true
dene "GitHub" "https://github.com/" || true
if dene "example.com" "https://example.com/"; then
  satir "Ağ seviyesi (tahmin)" "Full ya da Custom (izin listesi dışı alan adlarına erişiliyor)"
else
  satir "Ağ seviyesi (tahmin)" "Trusted, Custom ya da None"
fi

# --- GitHub --------------------------------------------------------------
baslik "GitHub ve git"
case "${GH_TOKEN:-}" in
  proxy-injected) satir "Kimlik" "GitHub proxy'si (gerçek token VM'de değil)" ;;
  "") satir "Kimlik" "GH_TOKEN tanımlı değil" ;;
  *)
    satir "Kimlik" "ortam değişkeninde kendi token'ın var"
    oner "GH_TOKEN ortam değişkeni olarak tanımlı; ortamı kullanan herkes okuyabilir. Gerekmiyorsa kaldır, GitHub proxy'si kimliği zaten ekliyor."
    ;;
esac
if git -C "$PROJE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  uzak="$(git -C "$PROJE" remote get-url origin 2>/dev/null | sed -E 's#://[^/@]+@#://#' || true)"
  satir "origin" "${uzak:-yok}"
  dal="$(git -C "$PROJE" branch --show-current 2>/dev/null)"
  satir "Dal" "${dal:-(ayrık HEAD)}"
  degisen="$(git -C "$PROJE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  satir "Commit edilmemiş" "$degisen dosya"
  if git -C "$PROJE" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    gonderilmemis="$(git -C "$PROJE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    satir "Push edilmemiş" "$gonderilmemis commit"
  else
    gonderilmemis="?"
    satir "Push edilmemiş" "dalın uzak karşılığı yok (hiç push edilmemiş)"
  fi
  if [ "$degisen" != "0" ] || [ "$gonderilmemis" != "0" ]; then
    oner "Kaydedilmemiş iş var. VM geçicidir: commit edip push et."
  fi
else
  satir "Git deposu" "hayır ($PROJE)"
fi

# --- Claude yapılandırması -----------------------------------------------
baslik "Claude yapılandırması"
if [ -f "$PROJE/CLAUDE.md" ]; then
  satir "CLAUDE.md" "var ($(wc -l <"$PROJE/CLAUDE.md" | tr -d ' ') satır)"
else
  satir "CLAUDE.md" "YOK"
  oner "Repoda CLAUDE.md yok. Her bulut oturumu sıfırdan başlar; test/lint komutlarını ve kuralları CLAUDE.md'ye yaz."
fi
ayar="$PROJE/.claude/settings.json"
if [ -f "$ayar" ] && var_mi jq; then
  ss="$(jq '[.hooks.SessionStart[]?.hooks[]?] | length' "$ayar" 2>/dev/null || echo '?')"
  satir "SessionStart hook'ları" "$ss"
  if [ "$ss" = "0" ]; then
    oner "SessionStart hook'u yok. Bağımlılıklar her oturumda elle mi kuruluyor? templates/scripts/cloud-session-start.sh'e bak."
  fi
else
  satir ".claude/settings.json" "yok"
fi
if [ -f "$PROJE/.mcp.json" ] && var_mi jq; then
  satir ".mcp.json sunucuları" "$(jq '.mcpServers | length' "$PROJE/.mcp.json" 2>/dev/null || echo '?')"
fi
for d in skills agents commands rules; do
  if [ -d "$PROJE/.claude/$d" ]; then
    satir ".claude/$d" "$(find "$PROJE/.claude/$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') öğe"
  fi
done
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  # shellcheck disable=SC2088 # etiket olarak yazdırılıyor
  satir "~/.claude/CLAUDE.md" "var (kişisel talimatlar)"
fi

# --- Servisler -----------------------------------------------------------
baslik "Servisler"
if var_mi pg_isready; then
  if pg_isready -q 2>/dev/null; then satir "PostgreSQL" "çalışıyor"; else satir "PostgreSQL" "kapalı (service postgresql start)"; fi
fi
if var_mi redis-cli; then
  if [ "$(redis-cli ping 2>/dev/null)" = "PONG" ]; then satir "Redis" "çalışıyor"; else satir "Redis" "kapalı (service redis-server start)"; fi
fi
if var_mi docker; then
  if docker info >/dev/null 2>&1; then satir "Docker" "çalışıyor"; else satir "Docker" "kapalı (dockerd'yi arka planda başlat)"; fi
fi

# --- Araçlar -------------------------------------------------------------
baslik "Araçlar"
surum() { # surum <etiket> <komut...>
  local s
  if var_mi "$2"; then
    s="$("${@:2}" 2>&1 | grep -v '^Picked up' | head -n1 | cut -c1-70)"
    satir "$1" "${s:-?}"
  fi
}
surum node node --version
surum python3 python3 --version
surum uv uv --version
surum pnpm pnpm --version
surum go go version
surum rustc rustc --version
surum java java -version
surum ruby ruby --version
surum php php --version
surum dotnet dotnet --version
surum docker docker --version
surum gh gh --version
if var_mi check-tools; then
  satir "Tam liste" "check-tools"
fi

# --- Zaman aşımları ------------------------------------------------------
baslik "Komut zaman aşımları"
satir "BASH_DEFAULT_TIMEOUT_MS" "${BASH_DEFAULT_TIMEOUT_MS:-tanımsız (varsayılan 2 dk)}"
satir "BASH_MAX_TIMEOUT_MS" "${BASH_MAX_TIMEOUT_MS:-tanımsız (varsayılan 10 dk)}"

# --- Öneriler ------------------------------------------------------------
baslik "Öneriler"
if [ "${#oneriler[@]}" -eq 0 ]; then
  echo "  Belirgin bir sorun yok."
else
  printf '  - %s\n' "${oneriler[@]}"
fi
exit 0
