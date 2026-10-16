# 06 · Güvenlik

## Gizli bilgileri nereye koymalı?

| Yöntem | VM'de görünür mü? | Ortamı kullanan diğerleri görür mü? | Ne için |
|---|---|---|---|
| Network secret | Hayır | Hayır (değer bir daha görüntülenemez) | HTTP başlığıyla giden API anahtarları |
| Ortam değişkeni | Evet | **Evet** | Gizli olmayan ayarlar |
| Setup script'e gömmek | Evet | **Evet** | **Asla** |
| Repoya commit etmek | Evet | Repoyu gören herkes | **Asla** |

- Proxy'nin ekleyemediği bir kimlik bilgisi (ör. setup script'te gereken bir token) mecburen ortam değişkeninde kalır. Bunun için **yalnızca senin kullandığın kişisel bir ortam** aç; paylaşılan ortama koyma.
- `GH_TOKEN` tanımlama. GitHub proxy'si kimliği zaten güvenli şekilde ekliyor.
- Claude'a gizli bilgi içeren dosyaları (ör. `.env`) commit etmemesini CLAUDE.md'de açıkça yaz.

## Ağ

- En dar seviyeyi seç. Çoğu iş için **Trusted** yeterli. **Full** ağ, Claude'un okuduğu bir web sayfasındaki ya da bağımlılık dosyasındaki kötü niyetli talimatların veri sızdırmasına daha geniş bir yüzey açar.
- Güvenilmeyen bir repoyu incelerken **None** seviyesinde bir ortam kullan. Claude Code'un kendi Anthropic API erişimi None'da da devam eder; yani None "hiçbir veri dışarı çıkmaz" anlamına gelmez.
- Kullanmadığın MCP connector'ları kapat. Connector trafiği ağ izin listesinden geçmez.

## GitHub

- Proxy dal silmeyi ve tag push'unu engeller, ama **hangi dala** push edileceğini kısıtlamaz. `main` ve sürüm dalları için branch protection ya da ruleset kur.
- Claude GitHub App'i yalnızca gereken repolara kur.
- Auto-fix inceleme yorumlarına senin hesabınla cevap yazar. Yorumla tetiklenen dağıtım ya da altyapı otomasyonu olan repolarda Auto-fix'i açma.

## Oturum paylaşımı

- Pro/Max'te **Public** paylaşım, claude.ai'a giriş yapmış herkese açıktır. Oturum özel repo kodunu ve komut çıktılarındaki gizli bilgileri içerebilir.
- **Settings > Claude Code > Sharing settings** bölümünden alıcılarda repo erişimi doğrulamasını ve adının gizlenmesini açabilirsin.

## Yerelden yükleme (bundle)

`claude --cloud` yerel repoyu yüklediğinde:

- İzlenmeyen dosyalar gitmez.
- macOS, Linux ve WSL'de `.env`, `*.tfvars`, `id_rsa`, `*.pem` gibi dosyalardaki commit edilmemiş değişiklikler dışarıda bırakılır.
- **Native Windows'ta bu filtre yok.** Commit edilmemiş değişiklikler, dosya adı ne olursa olsun olduğu gibi gider. Göndermek istemediğin değişiklikleri başlamadan önce stash et.

## Kuruluşlar için

- Paylaşılan ortamları Owner'lar yönetir. Paylaşılan ortamın değişkenlerine gizli bilgi koyma; network secret kullan.
- Kuruluşta IP allowlist açıksa Anthropic'te barındırılan bulut oturumları kimlik doğrulama hatası alır. Anthropic desteğinden muafiyet istemek gerekir.
- Zero Data Retention ya da HIPAA yapılandırması olan kuruluşlar ve müşteri tarafından yönetilen şifreleme anahtarı (CMEK) kullananlar bulut oturumu başlatamaz.

---

Kaynaklar: [Security and isolation](https://code.claude.com/docs/en/claude-code-on-the-web#security-and-isolation) · [Network secrets](https://code.claude.com/docs/en/cloud-environments#add-network-secrets)
