# 03 · Setup script ve SessionStart hook'ları

Bulut oturumunun hızlı açılması ve her seferinde aynı ortamı bulması, kurulumu doğru yere koymana bağlı.

## Hangisi ne için?

| | Setup script | SessionStart hook |
|---|---|---|
| Nerede tanımlanır | Ortam ayarları → **Setup script** | Repodaki `.claude/settings.json` |
| Ne zaman çalışır | Claude Code başlamadan **önce**. Önbellek varsa **hiç çalışmaz** | Claude Code başladıktan sonra, **her** oturumda (devam ettirilenler dahil) |
| Nerede çalışır | Sadece bulutta | Yerelde ve bulutta |
| Ne konur | Makinenin kendisi: apt paketleri, araç zincirleri, global CLI'lar, Docker imajları | Projenin kendisi: `npm install`, `pip install -r`, servis başlatma |
| Repoyla sürümlenir mi | Hayır | Evet |

Kısaca: **makineyi setup script, projeyi hook hazırlar.**

## Setup script

Ubuntu 24.04 üzerinde root olarak çalışan bir Bash betiği.

### Önbellekleme nasıl çalışır?

1. Bir ortamda ilk oturum açıldığında setup script çalışır.
2. **Yaklaşık 5 dakika içinde biterse** dosya sisteminin anlık görüntüsü alınır.
3. Sonraki oturumlar bu görüntüden başlar ve setup script'i **atlar**.
4. Önbellek şu durumlarda yeniden oluşturulur: setup script değiştiğinde, izinli alan adları değiştiğinde ve yaklaşık 7 gün dolduğunda.

Anlık görüntü **dosyaları** saklar, **çalışan süreçleri** saklamaz. Kurulan paketler, çekilen Docker imajları ve yazılan dosyalar kalır. Başlatılan bir veritabanı ya da `docker compose up` yığını kalmaz; onları her oturumda hook ile ya da Claude'a söyleyerek başlat.

Setup script'i değiştirdiğinde, çalışan oturumlar eski önbellekle devam eder. Değişikliği görmek için yeni oturum aç.

### Üç kural

1. **Sıfırla çık.** Betik sıfır dışı bir kodla biterse oturum **açılmaz**. Kritik olmayan adımlara `|| true` ekle.
2. **5 dakikanın altında kal.** Aksi halde önbellek oluşmaz ve her oturum yavaş açılır. Bağımsız kurulumları `&` ile paralel başlatıp `wait` ile bekle. Sığmayan tek büyük indirmeyi, arka planda başlatan bir hook'a taşı.
3. **Ağ erişimi gerekir.** None seviyesinde kurulumlar başarısız olur.

> ⚠️ **Tuzak:** Çıktıyı loglamak için `exec > >(tee log)` kullanıp ardından argümansız `wait` çağırırsan bash 5.2 `tee`'yi de bekler ve betik **hiç bitmez**. Bu rehberin denemelerinde yaşandı. Arka plan işlerinin PID'lerini toplayıp `wait "${pidler[@]}"` ile bekle.

### Hazır örnekler

| Dosya | Ne yapar | Bu VM'de ölçülen süre |
|---|---|---|
| [temel.sh](../templates/setup-scripts/temel.sh) | Paralel apt + global araç kurulumu iskeleti | ~5 sn |
| [dotnet.sh](../templates/setup-scripts/dotnet.sh) | .NET SDK 8'i Ubuntu deposundan kurar | ~24 sn |
| [docker-imajlari.sh](../templates/setup-scripts/docker-imajlari.sh) | dockerd'yi başlatır, imajları önbelleğe çeker, dockerd'yi düzgünce kapatır | ~15 sn |
| [kisisel-tercihler.sh](../templates/setup-scripts/kisisel-tercihler.sh) | `~/.claude/CLAUDE.md` yazar (yalnızca kendi ortamında kullan) | <1 sn |

## SessionStart hook

### Tanım

`.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/scripts/cloud-session-start.sh",
            "timeout": 900
          }
        ]
      }
    ]
  }
}
```

`$CLAUDE_PROJECT_DIR` repo köküne çözülür; böylece betik, oturumun çalışma dizini neresi olursa olsun bulunur.

### İyi bir hook betiğinin özellikleri

- **Sadece bulutta çalışır:** `[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0`. Hook'lar yerelde de çalıştığı için bu kontrol şart.
- **Gereksiz işi atlar:** Hook her oturum başlangıcında ve devam ettirmede çalışır. Kilit dosyalarının hash'ini sakla, değişmediyse kurulum yapma.
- **Kısa çıktı verir:** SessionStart'ın stdout'u Claude'un bağlamına eklenir; sınır 10.000 karakter. Kurulum loglarını dosyaya yaz, Claude'a yalnızca özeti ve hata olursa son satırları göster.
- **Ortamı kalıcı yapar:** `CLAUDE_ENV_FILE` dosyasına yazılan `export` satırları, sonraki her Bash komutundan önce çalıştırılır. Örnek: `export PATH="$PWD/node_modules/.bin:$PATH"`.
- **Oturumu engellemez:** SessionStart hatası oturumu durdurmaz. Yine de `exit 0` ile bitip hatayı çıktıda açıkça raporlamak daha nettir.
- **Zaman aşımı:** varsayılan 600 saniye; hook tanımında `"timeout"` (saniye) ile değiştirilir. `"async": true` hook'u arka plana alır ama o zaman Claude sonucunu beklemez.

### Hazır betik

[templates/scripts/cloud-session-start.sh](../templates/scripts/cloud-session-start.sh):

- Node (npm, pnpm, yarn, bun), Python (uv, poetry, pip), Ruby, PHP, Go ve Rust'ı kilit dosyalarından tanır.
- Hash ile atlar. `node_modules` ya da `.venv` silinmişse hash aynı olsa bile yeniden kurar.
- `node_modules/.bin` ve `.venv/bin`'i `CLAUDE_ENV_FILE` ile PATH'e ekler.
- `SESSION_START_SERVICES="postgresql redis-server docker"` ile servisleri başlatır.
- Bu VM'de ölçülen: ilk açılış ~8 sn (npm + pip + PostgreSQL + Redis), sonraki açılışlar ~0,04 sn.

Kendi projene eklemek için: `bash scripts/projeye-ekle.sh /proje/dizini`

### Bulutta hook sınırlamaları

- **Çok repolu oturumlarda** hiçbir reponun `.claude/settings.json` hook'u çalışmaz. Bu durumda bağımlılıkları setup script ile kur.
- Kullanıcı düzeyindeki `~/.claude/settings.json` hook'ları buluta gitmez.
- Her oturum başlangıcında çalıştığı için açılışa gecikme ekler. Hash ile atlama bu yüzden önemli.

## Karar tablosu

| İhtiyaç | Nereye |
|---|---|
| `apt install`, .NET/Flutter SDK, global CLI | Setup script |
| Büyük Docker imajlarını önceden çekmek | Setup script |
| `npm install`, `pip install -r`, `bundle install` | SessionStart hook |
| PostgreSQL / Redis / Docker başlatmak | SessionStart hook (ya da Claude'a söyle) |
| Herkesin bilmesi gereken proje kuralları, test komutları | Repodaki `CLAUDE.md` |
| Paylaşılan repoya koymak istemediğin kişisel tercihler | Kendi ortamının setup script'i → `~/.claude/CLAUDE.md` |
| Gizli API anahtarı | Network secret |

---

Kaynaklar: [Setup scripts](https://code.claude.com/docs/en/cloud-environments#setup-scripts) · [Hooks](https://code.claude.com/docs/en/hooks)
