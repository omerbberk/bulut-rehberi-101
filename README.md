# Claude Code Bulut Oturumları Rehberi

Claude Code'un bulut oturumlarını (claude.ai/code, Claude mobil uygulaması, `claude --cloud`) **daha hızlı, daha ucuz ve daha güvenli** kullanmak için pratik bir rehber. Projene kopyalayabileceğin, test edilmiş şablonlar da içinde.

> Bu bir topluluk rehberidir, Anthropic'in resmi yayını değildir. Bilgiler Ekim 2026'da [resmi dokümanlardan](https://code.claude.com/docs/en/claude-code-on-the-web) derlendi. Betikler gerçek bir bulut oturumunda denendi. Ürün hızlı değişiyor; çelişki olursa resmi doküman geçerlidir.

## Bir bakışta: bu sunucu ne?

| | |
|---|---|
| **Sahibi** | Anthropic. Her oturuma ayrı açılan izole bir sanal makine (VM) |
| **Sistem** | Ubuntu 24.04, x86_64 (senin bilgisayarın Mac/ARM olsa bile) |
| **Kaynak (yaklaşık)** | 4 vCPU · 16 GB RAM · 30 GB disk |
| **Ömür** | Birkaç dakika boşta kalınca duraklar, dosyalar korunur. Bir süre sonra geri alınır: sohbet geri gelir, push edilmemiş işler ve çalışan süreçler gelmez |
| **Ağ** | Varsayılan **Trusted**: paket kayıtları, GitHub, bulut SDK'ları. Gerisi engelli |
| **GitHub** | Kimlik bilgilerin VM'e hiç girmez; ayrı bir proxy ekler |
| **Ücret** | VM için ayrı ücret yok; planının kullanım limitinden düşer |

Ayrıntılar: [docs/01-sunucu-nedir.md](docs/01-sunucu-nedir.md)

## En önemli 12 alışkanlık

1. **Sık commit, sık push.** VM geçicidir; push edilmeyen her şey kaybolabilir.
2. **Makineyi bir kez kur, önbelleğe bırak.** Araç zincirlerini ortamın *setup script*'ine koy. Kurulum 5 dakikanın altında biterse dosya sisteminin anlık görüntüsü alınır ve sonraki oturumlar sıfırdan kurmaz.
3. **Proje bağımlılıklarını SessionStart hook'una koy.** `CLAUDE_CODE_REMOTE` ile yalnızca bulutta çalıştır, kilit dosyası değişmediyse atla. [Şablon](templates/scripts/cloud-session-start.sh)
4. **CLAUDE.md'yi repoya commit et.** Senin `~/.claude/` klasörün buluta gitmez; yalnızca repodakiler gider.
5. **Görevi bitiş kriteriyle ver.** Ör. "testler geçsin, `npm run lint` temiz olsun, PR aç". Claude'un kendini doğrulayabildiği görevler bulutta en iyi sonucu verir. [Görev şablonu](templates/gorev-sablonu.md)
6. **Planı yerelde yap, uygulamayı buluta gönder.** `claude --permission-mode plan` ile planla, planı repoya yazıp push et, sonra `claude --cloud "docs/plan.md'yi uygula"`.
7. **Bağımsız işleri paralel başlat**, ama her oturumun aynı kullanım limitinden harcadığını unutma.
8. **API anahtarlarını ortam değişkenine değil network secret'a koy.** Ortam değişkenlerini o ortamı kullanan herkes okuyabilir.
9. **Ağ erişimini en dar seviyede tut.** Gerekmedikçe **Full** açma; **Custom** ile yalnızca gereken alan adlarını ekle.
10. **Uzun işlerde zaman aşımını büyüt:** `BASH_DEFAULT_TIMEOUT_MS` ve `BASH_MAX_TIMEOUT_MS`.
11. **Bağlam dolunca `/compact`, konu değişince yeni oturum.** Bulutta `/clear` yok.
12. **PR açtıktan sonra Auto-fix'i aç.** CI hatalarını ve inceleme yorumlarını Claude takip etsin. Yorumla tetiklenen otomasyonların varsa önce dikkat et.

## İçindekiler

| Bölüm | Konu |
|---|---|
| [01 · Sunucu nedir?](docs/01-sunucu-nedir.md) | VM'in özellikleri, yaşam döngüsü, kurulu araçlar, buluta ne taşınır ne taşınmaz |
| [02 · Ortam ayarları](docs/02-ortam-ayarlari.md) | Ortamlar, ağ seviyeleri, ortam değişkenleri, network secret, GitHub proxy |
| [03 · Setup script ve hook'lar](docs/03-setup-script-ve-hooklar.md) | Önbellekleme, 5 dakika kuralı, SessionStart hook, hangisi ne zaman |
| [04 · İş akışları](docs/04-is-akislari.md) | `--cloud`, paralel görevler, teleport, takip mesajları, Auto-fix, paylaşım |
| [05 · Verimlilik](docs/05-verimlilik.md) | Limitler, açılış hızı, bağlam yönetimi, zaman aşımları |
| [06 · Güvenlik](docs/06-guvenlik.md) | Gizli bilgiler, ağ, GitHub, paylaşım riskleri |
| [07 · Sorun giderme](docs/07-sorun-giderme.md) | Belirti → sebep → çözüm tabloları |

## Hazır şablonlar

```
templates/
├── CLAUDE.md                       # Repo köküne konacak talimat dosyası iskeleti
├── .claude/settings.json           # SessionStart hook tanımı
├── scripts/cloud-session-start.sh  # Bulutta bağımlılıkları akıllıca kuran betik
├── setup-scripts/                  # Ortamın "Setup script" alanına yapıştırılacak örnekler
│   ├── temel.sh                    #   paralel apt + araç kurulumu iskeleti
│   ├── dotnet.sh                   #   .NET SDK
│   ├── docker-imajlari.sh          #   Docker imajlarını önbelleğe alma
│   └── kisisel-tercihler.sh        #   ~/.claude/CLAUDE.md'yi repoya koymadan taşıma
├── ortam-degiskenleri.env          # "Environment variables" alanı için örnek
└── gorev-sablonu.md                # Buluta verilecek görevler için istem şablonu
scripts/
├── projeye-ekle.sh                 # Şablonları kendi projene tek komutla ekler
└── bulut-doktoru.sh                # Bulut oturumunun röntgenini çeker
tests/
└── smoke.sh                        # Betiklerin otomatik testleri (CI'da da çalışır)
```

### Kendi projene ekle

```bash
git clone https://github.com/<kullanici>/claude-code-bulut-rehberi.git
bash claude-code-bulut-rehberi/scripts/projeye-ekle.sh /proje/dizinin
```

Betik var olan dosyaların üzerine yazmaz. `.claude/settings.json` zaten varsa hook'u `jq` ile ekler, ikinci kez çalıştırıldığında çoğaltmaz. Ardından değişiklikleri commit edip push et; bir sonraki bulut oturumu bunları kullanır. İlk mesajda Claude şöyle bir özet görür:

```
[cloud-session-start] Bulut oturumu hazırlığı:
- node: güncel, atlandı
- python: güncel, atlandı
- servis postgresql: çalışıyor
Ayrıntılı log: /root/.cache/claude-session-start/…/kurulum.log
```

### Ortamı teşhis et

Bir bulut oturumunda Claude'a şunu söyle:

> `bash scripts/bulut-doktoru.sh` çalıştır ve sonucu özetle.

Betik şunları raporlar: hangi oturumda olduğun, kaynaklar, disk kotası, ağ proxy'sinin son engellediği alan adları, GitHub erişim modu, push edilmemiş işler, servisler ve kurulu araçlar. Token ya da gizli değer yazdırmaz.

## Bu rehberdeki ölçümler

Betikler 16 Ekim 2026'da bir Claude Code bulut oturumunda çalıştırıldı:

| Ne | Sonuç |
|---|---|
| `cloud-session-start.sh`, ilk açılış (npm + pip + PostgreSQL + Redis) | ~8 sn |
| `cloud-session-start.sh`, değişiklik yokken | ~0,04 sn |
| `setup-scripts/dotnet.sh` | ~24 sn |
| `setup-scripts/docker-imajlari.sh` (2 imaj) | ~15 sn |
| `tests/smoke.sh` | 20/20 geçti |

Denemeler sırasında bulunan iki tuzak rehbere eklendi: `exec > >(tee …)` ile argümansız `wait` kullanınca setup script'in hiç bitmemesi ve `service docker start` komutunun ulimit hatası vermesi.

## Katkı

Hata, eskimiş bilgi ya da yeni bir ipucu gördüysen issue ya da PR aç. Bilgi eklerken mümkünse resmi doküman bağlantısı ver ve denemediğin bir şeyi "doğrulandı" diye yazma. Betik değişikliklerinde `shellcheck` ve `bash tests/smoke.sh` temiz geçmeli.

## Lisans

[MIT](LICENSE)

---

### English summary

A practical, Turkish-language guide to getting more out of Claude Code cloud sessions (claude.ai/code, the Claude mobile app, `claude --cloud`). It covers what the cloud VM is, environment configuration (network levels, environment variables, network secrets, GitHub proxy), setup scripts vs. SessionStart hooks and environment caching, workflows (`--cloud`, teleport, parallel sessions, Auto-fix), efficiency, security and troubleshooting. It also ships tested templates: a cloud-only SessionStart dependency installer with hash-based skipping, example setup scripts, a `CLAUDE.md` skeleton, a task prompt template and a diagnostics script.
