# 01 · Bu sunucu ne?

Claude Code'u bulutta başlattığında Claude senin bilgisayarında değil, Anthropic'in yönettiği bir sanal makinede (VM) çalışır. Bulut oturumunu şuralardan başlatabilirsin: claude.ai/code, Claude mobil uygulamasının **Code** sekmesi, masaüstü uygulamada **Cloud** seçeneği, terminalde `claude --cloud` ya da bir rutin.

## Kimin, nerede?

- **Sahibi:** Anthropic. Her oturum kendi izole VM'inde çalışır. Diğer oturumlardan ve senin makinenden ayrıdır.
- **Konum:** Resmi dokümanlarda belirli bir bölge taahhüdü yok. Dışarı giden trafik bir güvenlik proxy'sinden geçtiği için oturumun içinden "hangi ülkedeyim" sorgusu yapmak (ör. `ipinfo.io`) çoğu zaman engellenir.
- **İstisna:** Kuruluşun bir *self-hosted environment* tanımladıysa oturum kuruluşun kendi altyapısında çalışabilir. Bu rehber Anthropic'in barındırdığı ortamı anlatır.
- **Ücret:** VM için ayrı bir ücret yok. Bulut oturumları planının (Pro, Max, Team, Enterprise) kullanım limitinden düşer, diğer Claude kullanımınla aynı havuzdan.

## Donanım ve sistem

| Özellik | Değer |
|---|---|
| İşletim sistemi | Ubuntu 24.04 |
| Mimari | x86_64. Senin bilgisayarın Apple Silicon/ARM olsa bile. Önceden derlenmiş paket indiriyorsan Linux x86_64 sürümünü seç |
| CPU / RAM / Disk | Yaklaşık 4 vCPU, 16 GB RAM, 30 GB disk (Anthropic bunların değişebileceğini belirtiyor) |
| Kullanıcı | root |

`df` çıktısı yanıltıcı olabilir. Disk oturum başına sabit bir kotadır; asıl bakılacak değer "Avail" sütunudur. `no space left on device` alırsan büyük derleme çıktılarını ve önbellekleri sil; kota dolduğunda bile silme işlemi çalışır.

Bu sınırları aşan işler (çok büyük derlemeler, belleği yoğun testler) için iki yol var: [Remote Control](https://code.claude.com/docs/en/remote-control) ile kendi makinende çalışmak ya da kuruluşun self-hosted ortamını kullanmak.

## Yaşam döngüsü

```
  oluştur ──► çalış ──► (birkaç dk boşta) ──► DURAKLAT ──► (bir süre sonra) ──► GERİ ALINIR
                ▲                               │  dosyalar korunur               │
                └────────── mesaj gönder ───────┘                                 │
                                                       oturumu yeniden aç ──► YENİ VM
```

| Durum | Korunanlar | Kaybolanlar |
|---|---|---|
| Duraklatıldı, mesajla devam edildi | Aynı VM, dosyalar | Claude Code yeniden başlar; arka planda çalışan süreçlere güvenme |
| Geri alındı, oturum yeniden açıldı | Sohbet geçmişi, push edilmiş dallar | Push edilmemiş değişiklikler, arka plan komutları, alt ajanlar, kendi hızını ayarlayan `/loop` |

Sonuç: **sık commit, sık push.** Claude'a "her anlamlı adımdan sonra commit edip push et" demek iyi bir varsayılandır. Bunu CLAUDE.md'ye yazarsan her oturumda geçerli olur.

## Buluta ne taşınır, ne taşınmaz?

Oturum, reponun taze bir klonundan başlar. Kural basit: **repoya commit edilen her şey gelir, yalnızca senin makinende olan hiçbir şey gelmez.**

| Gelir ✅ | Gelmez ❌ |
|---|---|
| Repodaki `CLAUDE.md` | `~/.claude/CLAUDE.md` (kişisel talimatların) |
| `.claude/settings.json` içindeki hook ve izin kuralları (tek repolu oturumda) | `~/.claude/settings.json` ve oradaki hook'lar |
| `.mcp.json` içindeki MCP sunucuları (tek repolu oturumda) | `claude mcp add` ile yerel ya da kullanıcı kapsamında eklenen MCP sunucuları |
| `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/` | `~/.claude/skills/` vb. (claude.ai'da etkinleştirdiğin skill'ler ise otomatik yüklenir) |
| Kuruluşun sunucu tarafında yönetilen ayarları | Repodaki `enabledPlugins` ile açılan plugin'ler (bulutta kurulmaz) |
| Ortama tanımlı network secret'lar | AWS SSO gibi tarayıcıyla giriş gerektiren kimlik doğrulama |

İpuçları:

- Bir MCP sunucusunu bulutta da kullanmak için `claude mcp add --scope project ...` ile ekle. Bu komut `.mcp.json` dosyasını yazar; onu commit et.
- Kişisel talimatlarını paylaşılan repoya koymak istemiyorsan, **kendi** ortamının setup script'inde `~/.claude/CLAUDE.md` dosyasını oluştur: [örnek](../templates/setup-scripts/kisisel-tercihler.sh).
- Plugin'den gelen skill/agent/command'lara bulutta ihtiyacın varsa dosyalarını doğrudan repodaki `.claude/` altına koy.

## Hazır kurulu araçlar

| Kategori | İçerik |
|---|---|
| Python | Python 3.x, pip, poetry, uv, black, mypy, pytest, ruff |
| Node.js | 20, 21, 22 (varsayılan 22), npm, yarn, pnpm, bun, eslint, prettier, chromedriver |
| Ruby | 3.1, 3.2, 3.3, gem, bundler, rbenv |
| PHP | 8.3, Composer |
| Java | OpenJDK 21, Maven, Gradle |
| Go | Modül desteğiyle |
| Rust | rustc, cargo |
| C/C++ | GCC, Clang, cmake, ninja, conan |
| Docker | docker, dockerd, docker compose |
| Veritabanı | PostgreSQL 16, Redis 7.0. Kurulu ama **çalışmıyor** |
| Araçlar | git, gh, jq, yq, ripgrep, tmux, vim, nano |

- Sürümleri görmek için Claude'a `check-tools` komutunu çalıştırmasını söyle. Bu, VM'de kurulu bir kabuk komutudur, `/` ile yazılan bir komut değildir.
- Başka bir Node sürümü için `/opt/node20/bin` gibi dizini `PATH`'in başına ekle.
- Servisleri başlatmak için `service postgresql start` ve `service redis-server start` kullanılır.
- Docker daemon'u varsayılan olarak çalışmıyor. Bu rehberin denemesinde `service docker start` bir ulimit hatası verdi, `dockerd`'yi doğrudan arka planda başlatmak ise çalıştı. [Başlangıç betiği](../templates/scripts/cloud-session-start.sh) bunu `SESSION_START_SERVICES="docker"` ile yapar.
- Listede olmayan araç zincirleri (ör. .NET SDK) setup script ile kurulur: [örnek](../templates/setup-scripts/dotnet.sh).
- Bun kurulu ama proxy üzerinden paket indirirken bilinen sorunları var. Paket kurulumu için npm veya pnpm tercih et.

## Oturumu tanıtan değişkenler

| Değişken | Değer | Ne işe yarar |
|---|---|---|
| `CLAUDE_CODE_REMOTE` | `true` | Betiklerde "bulutta mıyım?" kontrolü. Yerelde hiçbir zaman `true` olmaz |
| `CLAUDE_CODE_REMOTE_SESSION_ID` | `cse_...` | Oturum bağlantısı üretmek için |
| `GH_TOKEN`, `GITHUB_TOKEN` | `proxy-injected` | Kendin token tanımlamadıysan bu bir yer tutucudur; gerçek kimlik bilgisi VM'den çıkarken proxy tarafından eklenir |

Oturumun bağlantısını bir rapora ya da mesaja koymak için:

```bash
echo "https://claude.ai/code/${CLAUDE_CODE_REMOTE_SESSION_ID/#cse_/session_}"
```

Claude'un bulutta oluşturduğu commit'lere zaten bir `Claude-Session: <url>` satırı, PR açıklamalarına da oturum bağlantısı eklenir. İstemiyorsan `attribution.sessionUrl` ayarını `false` yap.

## VM'e senin doğrudan shell erişimin yok

Bütün komutları Claude çalıştırır. "Testleri çalıştır", "postgres'i başlat", "`bash scripts/bulut-doktoru.sh` çalıştır" gibi isteklerini istem olarak yaz.

---

Kaynaklar: [Use Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web) · [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments)
