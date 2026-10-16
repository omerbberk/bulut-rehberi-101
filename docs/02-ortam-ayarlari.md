# 02 · Ortam ayarları

Her bulut oturumu bir **ortamda** (environment) çalışır. Ortam; ağ erişim seviyesi, ortam değişkenleri, network secret'lar ve setup script'ten oluşan kayıtlı bir yapılandırmadır. Aynı ortam her yerde geçerlidir: web, mobil, masaüstü, `claude --cloud`, rutinler.

## Ortamı nereden düzenlerim?

- **Yeni oturum ekranında** (claude.ai/code): mesaj kutusunun altındaki ilk kontrol. Yeni ortam için **New environment**, var olanı düzenlemek için satırın üzerine gelip ayar simgesine tıkla.
- **Çalışan bir oturumda:** oturum başlığının yanındaki ok → **Edit cloud environment**.
- **Terminalden varsayılanı seçmek:** `/remote-env`. Bu komut sadece seçim yapar, ortam oluşturmaz ya da düzenlemez. Seçimin kullanıcı ayarlarına `remote.defaultEnvironmentId` olarak yazılır.
- Ortam silinemez, yalnızca arşivlenir. Arşivlenen ortamda çalışan oturumlar devam eder, yeni oturum açılamaz.

### Varsayılan ortam

İlk kurulumda **Default** adında bir ortam oluşturulur: ağ **Trusted**, ortam değişkeni yok, setup script yok.

### Önerilen düzen

Her şeyi tek bir ortama yığmak yerine işe göre ortamlar aç:

| Ortam | Ağ | Ne zaman |
|---|---|---|
| `gunluk` | Trusted | Günlük kod işleri |
| `kapali` | None | Güvenilmeyen bir repoyu incelemek, sadece okuma ve analiz |
| `proje-x` | Custom (varsayılan liste + projenin API'leri) | Bir projenin harici servisleri gerektiğinde |
| `dotnet` | Trusted + setup script | Hazır kurulu olmayan bir araç zinciri gerektiğinde |

Team ve Enterprise planlarında bir Owner, ortamı **kuruluşla paylaşabilir**; böylece herkes aynı yapılandırmayı kullanır.

## Ağ erişim seviyeleri

| Seviye | Dışarı bağlantılar |
|---|---|
| **None** | Oturumun ağından hiçbir şey |
| **Trusted** (varsayılan) | İzinli liste: paket kayıtları, GitHub, Docker kayıtları, bulut SDK'ları |
| **Full** | Her alan adı |
| **Custom** | Senin listen; istersen varsayılan liste de eklenir |

Hangi seviyeyi seçersen seç, şunlar ağ izin listesinden **geçmez** ve erişilebilir kalır:

- GitHub (ayrı bir GitHub proxy'si üzerinden)
- Etkinleştirdiğin MCP connector'lar (trafikleri Anthropic sunucuları üzerinden gider)
- Network secret tanımladığın alan adları
- Claude Code'un kendi Anthropic API istekleri (None seviyesinde bile)

Ağ ayarını değiştirdiğinde mevcut oturumlar yaklaşık bir dakika içinde yeni ayara geçer; yeni oturum açman gerekmez.

### Custom ile alan adı eklemek

**Network access → Custom** seç, **Allowed domains** alanına her satıra bir alan adı yaz:

```text
api.example.com
*.internal.example.com
```

`*.` önekli satır tüm alt alan adlarını kapsar. Paket kurulumlarının bozulmaması için **Also include default list of common package managers** kutusunu işaretli bırak.

Varsayılan Trusted listesinin tamamı: [Default allowed domains](https://code.claude.com/docs/en/cloud-environments#default-allowed-domains)

## Ortam değişkenleri

`.env` biçiminde, satır başına `ANAHTAR=deger`:

```text
NODE_ENV=development
BASH_DEFAULT_TIMEOUT_MS=600000
```

- Tırnaksız bir değerde `#` yorum başlatır. `#` içeren ya da birden çok satıra yayılan değerleri tırnak içine al.
- **Bu değerleri o ortamı kullanan herkes okuyabilir.** Gizli anahtar koyma, network secret kullan.
- Değişiklik çalışan oturuma hemen yansımaz. Oturum değerleri, VM duraklatıldıktan sonra geri yüklendiğinde ya da yeniden kurulduğunda okur. Değer hemen lazımsa komutun önüne yaz (`LOG_LEVEL=trace npm test`) ya da yeni oturum aç.
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` değerini bulutta oturumun kendisi belirler; buraya yazman etkisizdir. `OTEL_*` değişkenleri, çalıştırılan komutlara geçirilmez.

Hazır örnek: [templates/ortam-degiskenleri.env](../templates/ortam-degiskenleri.env)

## Network secret: anahtarı görmeden kullanmak

API anahtarını ortama kaydedersin. Anthropic'in proxy'si bu anahtarı, istek VM'den çıktıktan **sonra** ekler. Anahtar VM'e, dosyalara ya da ortam değişkenlerine hiç girmez.

Kurulum: ortamı düzenle → **Network secrets** → **Add secret**

- **Name:** bir etiket, ör. `Fatura API`
- **Allowed websites:** `api.example.com` (alt alan adları için `*.` öneki)
- **Custom headers:** varsayılan olarak `Authorization` başlığı ve `Bearer` öneki gelir; değer olarak anahtarını yapıştır. `X-Api-Key` gibi çıplak değer bekleyen başlıklarda adı değiştir ve öneki temizle.

Kaydettikten sonra değer bir daha görüntülenemez; değiştirmek için silip yeniden eklersin. Çalıştığını doğrulamak için Claude'a `curl https://api.example.com/...` çalıştırmasını söyle. API anahtar varmış gibi yanıt verir, ama anahtar hiçbir dosyada ya da değişkende görünmez.

Secret'ın **hiçbir zaman** eklenmediği istekler:

- GitHub (onun kendi proxy'si var)
- Anthropic API ve herkese açık paket kayıtları: npm, PyPI, crates.io, Go proxy, JSR
- **Setup script içindeki istekler.** Proxy, Claude Code başladıktan sonra devreye girer; setup script ondan önce çalışır.

Kimler ekleyebilir: Pro, Max ve Team'de kendi ortamına herkes ekleyebilir. Enterprise'da kuruluş yöneticisi rolü gerekir. Paylaşılan ortamlara secret'ı Owner'lar ekler.

## GitHub proxy

- Gerçek GitHub token'ın VM'e girmez. VM'deki git, kapsamı sınırlı bir kimlik kullanır; proxy bunu gerçek token'la değiştirir.
- **Push kısıtları:** dal silme ve tag push'u reddedilir. Hangi dala push edilebileceği ise sınırlanmaz. Önemli dallar için GitHub'da branch protection ya da ruleset kur.
- **Repo kapsamı:** API istekleri yalnızca oturuma bağlı repolar için çalışır. Diğerleri `GitHub access to ... is not enabled for this session` 403'ünü döner. Buna herkese açık repoların `codeload.github.com` arşiv indirmeleri de dahil.
- **GraphQL kapalı:** `gh pr ...`, `gh issue ...` gibi GraphQL kullanan komutlar 403 alır. REST kullan: `gh api repos/OWNER/REPO/pulls`. Projects v2 gibi yalnızca GraphQL'de olan API'lere erişilemez.
- Kendi `GH_TOKEN`'ını ortam değişkeni olarak tanımlarsan VM'e olduğu gibi gelir ve ortamı kullanan herkes okuyabilir. Gerekmedikçe tanımlama.

### GitHub'ı bağlama yolları

| Yöntem | Erişilebilen repolar | Not |
|---|---|---|
| Claude GitHub App | Herkese açık tüm repolar + App'in kurulu olduğu özel repolar | Auto-fix ve Projects için gerekli |
| Terminalde `/web-setup` | Yerel `gh` token'ının erişebildiği tüm repolar | `gh` kullanan bireysel geliştiriciler için pratik |

Bağlantı ya da App kurulumu: [claude.ai/connect-github](https://claude.ai/connect-github)

---

Kaynak: [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments)
