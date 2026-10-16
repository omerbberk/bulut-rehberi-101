#!/bin/bash
# Büyük Docker imajlarını ortam önbelleğine almak için setup script örneği.
#
# Ortam önbelleği bir dosya sistemi anlık görüntüsüdür: çekilen imajlar kalır, çalışan
# konteynerler kalmaz. Konteynerleri her oturumda yine başlatman gerekir
# (ör. SESSION_START_SERVICES="docker" ve ardından Claude'a "docker compose up -d" de).
#
# Not: Bulut VM'inde dockerd varsayılan olarak çalışmıyor ve "service docker start" bir
# ulimit hatasıyla başarısız olabiliyor. Bu yüzden dockerd burada doğrudan başlatılıyor.

IMAJLAR=(
  postgres:16-alpine
  redis:7-alpine
)

if ! docker info >/dev/null 2>&1; then
  setsid -f dockerd >/var/log/dockerd-setup.log 2>&1 </dev/null
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
fi

for imaj in "${IMAJLAR[@]}"; do
  docker pull -q "$imaj" || echo "UYARI: $imaj çekilemedi" &
done
wait

# dockerd'yi düzgünce kapat: anlık görüntüde yarım kalmış durum ve eski pid dosyası kalmasın
if pid="$(pidof dockerd)"; then
  kill "$pid"
  for _ in $(seq 1 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
fi

exit 0
