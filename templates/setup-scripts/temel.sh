#!/bin/bash
# Temel setup script iskeleti.
# Bulut ortamının ayarları → "Setup script" alanına yapıştır, ihtiyacına göre düzenle.
#
# Ubuntu 24.04 üzerinde root olarak, Claude Code başlamadan ÖNCE çalışır.
# Üç kural:
#   1. Sıfırla çık. Sıfır dışı çıkış kodu oturumun açılmasını engeller.
#   2. ~5 dakikanın altında kal. Aşarsan ortam önbelleğe alınmaz, her oturum yavaş açılır.
#   3. Ağ erişimi gerekir (None seviyesinde kurulumlar başarısız olur).
# Bu betikteki isteklere network secret eklenmez (proxy, Claude Code başladıktan sonra devreye girer).
#
# Dikkat: "exec > >(tee log)" gibi süreç yerine koyma ile argümansız "wait" birlikte
# kullanılırsa bash 5.2 tee'yi de bekler ve betik hiç bitmez. Aşağıda PID'ler tek tek bekleniyor.

export DEBIAN_FRONTEND=noninteractive
basla=$SECONDS
pidler=()

# 1) apt paketleri: tek apt-get çağrısında topla
APT_PAKETLERI=(
  shellcheck
  # postgresql-client
  # graphviz
)

# 2) Bağımsız kurulumları paralel başlat
{
  apt-get update -qq &&
    apt-get install -y -qq --no-install-recommends "${APT_PAKETLERI[@]}"
} || echo "UYARI: apt kurulumu başarısız" &
pidler+=($!)

# { npm install -g --silent @mermaid-js/mermaid-cli || echo "UYARI: npm global kurulum başarısız"; } &
# pidler+=($!)
# { pip install -q pre-commit || echo "UYARI: pip kurulumu başarısız"; } &
# pidler+=($!)

# 3) Hepsini bekle
wait "${pidler[@]}"

echo "Setup tamamlandı: $((SECONDS - basla)) sn"
exit 0
