# 07 · Sorun giderme

İlk adım: Claude'a `bash scripts/bulut-doktoru.sh` çalıştırmasını ve sonucu özetlemesini söyle. Betik; kaynakları, disk kotasını, proxy'nin son engellediği alan adlarını, GitHub erişim modunu, push edilmemiş işleri ve servisleri raporlar.

## Ağ

| Belirti | Sebep | Çözüm |
|---|---|---|
| `curl: (56) CONNECT tunnel failed, response 403` | Alan adı ortamın ağ politikasında izinli değil | Ortamı düzenle → Network access → Custom ile alan adını ekle ("default list of common package managers" işaretli kalsın) ya da daha geniş bir seviye seç. Aynı isteği tekrar denemek işe yaramaz |
| `certificate verify failed`, `self-signed certificate in chain`, PKIX hataları | Araç, proxy'nin CA paketini okumuyor | Aracın CA ayarını `/root/.ccr/ca-bundle.crt`'ye yönlendir (`NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `GIT_SSL_CAINFO` …). TLS doğrulamasını **kapatma** |
| Proxy'den `405 Method Not Allowed` | Araç düz HTTP proxy isteği gönderiyor (eski axios ya da `HTTP_PROXY` kullanan bir araç) | axios'u güncelle ya da o araç için `HTTP_PROXY`'yi kaldır; yalnızca `HTTPS_PROXY` destekleniyor |
| Bun ile paket kurulumu başarısız | Bun'ın proxy uyumluluk sorunu | npm ya da pnpm kullan |
| Network secret eklendi ama API 401 veriyor | Host eşleşmiyor ya da iki secret'ın host'ları çakışıyor | Ortam ayarlarındaki listede secret'ın altında **Not sent** notu var mı bak. Host'ları tam eşleşmeden çakışan iki secret için uyarı çıkmaz ve yalnızca biri gönderilir; birini sil |
| Setup script içinde API anahtarı çalışmıyor | Secret'lar setup script isteklerine eklenmez | O adımı Claude Code başladıktan sonra çalışan bir SessionStart hook'una taşı |

Proxy ayrıntıları için Claude'a `/root/.ccr/README.md` dosyasını okumasını söyleyebilirsin. VM'deki bu dosya, hata türlerine göre düzeltmeleri listeliyor.

## GitHub

| Belirti | Sebep | Çözüm |
|---|---|---|
| `GitHub GraphQL is not available from Claude Code sessions` | `gh pr` ve `gh issue` gibi komutlar GraphQL kullanıyor; proxy GraphQL'e izin vermiyor | REST kullan: `gh api repos/OWNER/REPO/pulls`, `gh api repos/OWNER/REPO/issues` |
| `GitHub access to ... is not enabled for this session` | Repo bu oturuma bağlı değil | Yeni oturumu o repo seçili olarak başlat. Özel repoysa Claude GitHub App'i kur ya da [claude.ai/connect-github](https://claude.ai/connect-github) üzerinden yeniden bağlan |
| Tag push'u ya da dal silme reddedildi | Proxy bunlara izin vermez | Tag ve dal silme işlerini yerelden ya da GitHub arayüzünden yap |
| `gh auth status` "token invalid" diyor | `GH_TOKEN` yalnızca `proxy-injected` yer tutucusu | Normal. `gh api` çağrıları bağlı repolar için çalışır; `gh auth login` gerekmez |

## Oturum ve ortam

| Belirti | Sebep | Çözüm |
|---|---|---|
| Oturum açılmıyor, kurulumda hata veriyor | Setup script sıfır dışı kodla çıktı | Hangi komutun düştüğünü bul; kritik olmayan adımlara `\|\| true` ekle |
| Setup script hiç bitmiyor | Sık görülen bir sebep: `exec > >(tee …)` ile argümansız `wait` birlikte kullanılmış | PID'leri topla, `wait "${pidler[@]}"` kullan ([temel.sh](../templates/setup-scripts/temel.sh)) |
| Her oturum yavaş açılıyor | Setup script ~5 dakikayı aşıyor, önbellek oluşmuyor | Paralelleştir; büyük indirmeleri hook'ta arka plana al |
| `Session creation failed` ya da hazırlıkta takılma | VM ayrılamadı | [status.claude.com](https://status.claude.com)'a bak, bir dakika sonra tekrar dene, repo erişimini kontrol et |
| Ortam değişkeni değişikliği görünmüyor | Çalışan oturum değeri VM geri yüklenince okur | Değeri komutun önüne yaz (`X=1 npm test`) ya da yeni oturum aç |
| Setup script değişikliği görünmüyor | Mevcut oturum eski önbellekten çalışıyor | Yeni oturum aç |
| SessionStart hook'u çalışmıyor | Çok repolu oturum, hook kullanıcı ayarlarında ya da yerel bir dosyada | Tek repolu oturum kullan ya da kurulumu setup script'e taşı; hook'u repodaki `.claude/settings.json`'a koy ve commit et |
| Repodaki plugin'ler yüklenmiyor | Bulut `enabledPlugins`'i kurmaz | Skill, agent ve command dosyalarını doğrudan `.claude/` altına commit et |
| `~/.claude/CLAUDE.md` talimatların uygulanmıyor | Kullanıcı dosyaları buluta gitmez | Repoya koy ya da kişisel ortamının setup script'inde yazdır |
| `no space left on device` | Oturumun disk kotası doldu | Derleme çıktılarını, önbellekleri, kullanılmayan Docker imajlarını sil. Gerekirse işi push edip yeni oturum aç |
| Oturuma dönünce arka plan işleri yok | VM geri alındı ve yeniden kuruldu | Sohbet geri gelir; arka plan işlerini ve `/loop`'u yeniden başlat |
| `service docker start` ulimit hatası veriyor | VM'de ulimit ayarı yapılamıyor | `dockerd`'yi doğrudan arka planda başlat (`SESSION_START_SERVICES="docker"`) |

## Terminal ve teleport

| Belirti | Sebep | Çözüm |
|---|---|---|
| `Unable to get organization UUID` | API anahtarıyla giriş yapılmış ya da hesap bilgisi eski | `claude auth login` ile claude.ai hesabınla gir |
| `Cloud sessions aren't available with <provider>` | Claude Code üçüncü taraf bir sağlayıcıya ayarlı | Sağlayıcı ayarını kaldır (ör. `CLAUDE_CODE_USE_BEDROCK`), `claude auth login` ile gir |
| Teleport: dal bulunamadı | Oturumun dalı push edilmemiş | Bulut oturumunda Claude'a push ettir |
| Teleport: yanlış repo | Fork'tan ya da başka bir repodan çalıştırıyorsun | Oturumun reposunun bir klonunda çalıştır |
| Kuruluşta tüm bulut oturumları kimlik doğrulama hatası veriyor | Kuruluşta IP allowlist açık | Anthropic desteğinden muafiyet iste |

---

Kaynak: [Troubleshooting](https://code.claude.com/docs/en/claude-code-on-the-web#troubleshooting)
