#!/bin/bash
# .NET SDK kurulumu (bulut VM'inde hazır kurulu değil).
# Ubuntu 24.04'ün kendi deposundan kurar; archive.ubuntu.com varsayılan (Trusted) izin listesinde.
# Önerilen ortam değişkenleri: DOTNET_CLI_TELEMETRY_OPTOUT=1 ve DOTNET_NOLOGO=1

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq &&
  apt-get install -y -qq --no-install-recommends dotnet-sdk-8.0 ||
  echo "UYARI: .NET SDK kurulamadı" >&2

dotnet --version || true

# Kurulum başarısız olsa da oturum açılsın; Claude eksik aracı fark edip bildirir
exit 0
