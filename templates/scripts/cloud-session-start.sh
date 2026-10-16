#!/usr/bin/env bash
# Claude Code bulut oturumu başlangıç betiği (Claude Code Bulut Rehberi)
#
# .claude/settings.json içindeki SessionStart hook'u tarafından çağrılır.
#   - Yalnızca bulutta çalışır (CLAUDE_CODE_REMOTE=true). Yerelde hiçbir şey yapmaz.
#   - Kilit dosyalarına bakarak bağımlılıkları kurar: Node, Python, Ruby, PHP, Go, Rust.
#   - Kilit dosyaları son başarılı kurulumdan beri değişmediyse kurulumu atlar.
#   - Kurulum çıktısını log dosyasına yazar; Claude'a yalnızca kısa bir özet verir
#     (SessionStart hook'unun stdout'u Claude'un bağlamına eklenir).
#   - node_modules/.bin ve .venv/bin'i CLAUDE_ENV_FILE ile sonraki komutların PATH'ine ekler.
#
# Ayarlar (bulut ortamının "Environment variables" alanından verilebilir):
#   SESSION_START_SERVICES  Başlatılacak servisler, boşlukla ayrılmış: "postgresql redis-server docker"
#   SESSION_START_SKIP      Atlanacak adımlar: "node python ruby php go rust"
#   SESSION_START_FORCE=1   Hash'lere bakmadan her şeyi yeniden kur

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

set -uo pipefail

# cd'den önce: betik göreli yolla çağrıldıysa da kendi yolunu bulabilsin
SELF="$(realpath "${BASH_SOURCE[0]}")"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR" || exit 0

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-session-start/$(printf '%s' "$PROJECT_DIR" | sha256sum | cut -c1-12)"
LOG="$STATE_DIR/kurulum.log"
mkdir -p "$STATE_DIR"
: >"$LOG"

ozet=()
hatalar=""

# Verilen dosyaların (var olanların) ve bu betiğin birleşik hash'i.
# Betiğin kendisi de dahil, böylece betik değişince her şey yeniden kurulur.
parmak_izi() {
  local f
  for f in "$@" "$SELF"; do
    if [ -f "$f" ]; then sha256sum "$f"; fi
  done | sha256sum | cut -c1-64
}

# adim <ad> <olması-gereken-yol|""> <hash'lenecek dosyalar...> -- <komut...>
adim() {
  local ad="$1" gerekli="$2"
  shift 2
  local dosyalar=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    dosyalar+=("$1")
    shift
  done
  shift

  if [[ " ${SESSION_START_SKIP:-} " == *" $ad "* ]]; then
    ozet+=("$ad: atlandı (SESSION_START_SKIP)")
    return
  fi

  local damga="$STATE_DIR/$ad.sha256"
  if [ "${SESSION_START_FORCE:-0}" != "1" ] && [ -f "$damga" ] &&
    [ "$(cat "$damga")" = "$(parmak_izi "${dosyalar[@]}")" ] &&
    { [ -z "$gerekli" ] || [ -e "$gerekli" ]; }; then
    ozet+=("$ad: güncel, atlandı")
    return
  fi

  # Önce eski damgayı sil: kurulum yarıda kalırsa bir sonraki oturum yeniden dener
  rm -f "$damga"
  local bas=$SECONDS
  printf '\n===== %s: %s =====\n' "$ad" "$*" >>"$LOG"
  if "$@" >>"$LOG" 2>&1 </dev/null; then
    # Kurulum kilit dosyasını güncellemiş olabilir; hash'i kurulumdan sonra al
    parmak_izi "${dosyalar[@]}" >"$damga"
    ozet+=("$ad: kuruldu ($((SECONDS - bas)) sn) → $*")
  else
    ozet+=("$ad: BAŞARISIZ → $*")
    hatalar+=$'\n'"--- $ad: logun son satırları ---"$'\n'"$(tail -n 20 "$LOG" | cut -c1-200)"
  fi
}

ortama_ekle() {
  [ -n "${CLAUDE_ENV_FILE:-}" ] || return 0
  # Hook aynı oturumda birden çok kez çalışabilir (startup, resume); satırı çoğaltma
  grep -qxF -- "$1" "$CLAUDE_ENV_FILE" 2>/dev/null || printf '%s\n' "$1" >>"$CLAUDE_ENV_FILE"
}

# shellcheck disable=SC2317 # adim üzerinden dolaylı çağrılır
pip_kur() {
  local f
  for f in requirements.txt requirements-dev.txt; do
    if [ -f "$f" ]; then pip install -r "$f" || return 1; fi
  done
}

servis_baslat() {
  case "$1" in
    docker)
      # Bulut VM'inde "service docker start" ulimit hatası verebiliyor; dockerd'yi doğrudan başlat
      docker info >/dev/null 2>&1 && return 0
      setsid -f dockerd >>"$STATE_DIR/dockerd.log" 2>&1 </dev/null
      local _
      for _ in $(seq 1 30); do
        docker info >/dev/null 2>&1 && return 0
        sleep 1
      done
      return 1
      ;;
    *) service "$1" start ;;
  esac
}

# --- Node.js -------------------------------------------------------------
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then
    adim node node_modules package.json pnpm-lock.yaml -- pnpm install --config.confirmModulesPurge=false
  elif [ -f yarn.lock ]; then
    adim node node_modules package.json yarn.lock -- yarn install
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then
    # Not: bun'ın bulut proxy'siyle bilinen sorunları var; başarısız olursa npm/pnpm'e geç
    adim node node_modules package.json bun.lock bun.lockb -- bun install
  else
    adim node node_modules package.json package-lock.json -- npm install
  fi
  ortama_ekle "export PATH=\"$PROJECT_DIR/node_modules/.bin:\$PATH\""
fi

# --- Python --------------------------------------------------------------
venv=0
if [ -f uv.lock ]; then
  adim python .venv pyproject.toml uv.lock -- uv sync
  venv=1
elif [ -f poetry.lock ]; then
  adim python .venv pyproject.toml poetry.lock -- env POETRY_VIRTUALENVS_IN_PROJECT=true poetry install --no-interaction
  venv=1
elif [ -f requirements.txt ]; then
  adim python "" requirements.txt requirements-dev.txt -- pip_kur
fi
if [ "$venv" = 1 ]; then
  ortama_ekle "export VIRTUAL_ENV=\"$PROJECT_DIR/.venv\""
  ortama_ekle "export PATH=\"$PROJECT_DIR/.venv/bin:\$PATH\""
fi

# --- Diğer ekosistemler --------------------------------------------------
if [ -f Gemfile ]; then adim ruby "" Gemfile Gemfile.lock -- bundle install; fi
if [ -f composer.json ]; then adim php vendor composer.json composer.lock -- composer install --no-interaction; fi
if [ -f go.mod ]; then adim go "" go.mod go.sum -- go mod download; fi
if [ -f Cargo.toml ]; then adim rust "" Cargo.toml Cargo.lock -- cargo fetch; fi

# --- Servisler -----------------------------------------------------------
for s in ${SESSION_START_SERVICES:-}; do
  printf '\n===== servis: %s =====\n' "$s" >>"$LOG"
  if servis_baslat "$s" >>"$LOG" 2>&1 </dev/null; then
    ozet+=("servis $s: çalışıyor")
  else
    ozet+=("servis $s: BAŞLATILAMADI")
    hatalar+=$'\n'"--- servis $s: logun son satırları ---"$'\n'"$(tail -n 10 "$LOG" | cut -c1-200)"
  fi
done

# --- Claude için özet (stdout bağlama eklenir) ---------------------------
echo "[cloud-session-start] Bulut oturumu hazırlığı:"
if [ "${#ozet[@]}" -eq 0 ]; then
  echo "- Tanınan bağımlılık dosyası yok, yapılacak iş yok"
else
  printf -- '- %s\n' "${ozet[@]}"
fi
echo "Ayrıntılı log: $LOG"
if [ -n "$hatalar" ]; then
  echo
  echo "Bazı adımlar başarısız oldu. Bunlara bağlı işe başlamadan önce sorunu çöz ya da kullanıcıya bildir."
  echo "Ağ kaynaklı bir 403 ise hangi alan adının engellendiğini raporla; tekrar tekrar deneme.$hatalar"
fi

# SessionStart hatası oturumu durdurmaz; sonucu yukarıda raporladık
exit 0
