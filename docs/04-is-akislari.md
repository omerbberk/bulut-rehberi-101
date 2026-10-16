# 04 · İş akışları

## Oturumu nereden başlatırım?

- **Tarayıcı:** [claude.ai/code](https://claude.ai/code)
- **Mobil:** Claude uygulaması → **Code** sekmesi
- **Masaüstü uygulaması:** oturum başlatırken **Local** yerine **Cloud**
- **Terminal:** `claude --cloud "görev"`
- **Rutinler:** zamanlanmış ya da tetiklenen her çalıştırma bir bulut oturumudur

Bulut oturumu dizüstü bilgisayarını kapatsan da çalışmaya devam eder; herhangi bir cihazdan bakıp yönlendirebilirsin.

## Terminalden buluta

```bash
claude --cloud "src/auth/login.ts içindeki kimlik doğrulama hatasını düzelt"
```

- Bulut, **yerel çalışma kopyanı değil**, GitHub'daki uzak dalını klonlar. Yerel commit'lerin varsa önce push et.
- Repoda remote yoksa ya da Claude GitHub App kurulu değilse yerel repo paketlenip doğrudan yüklenir. Sınırlar: 100 MB, izlenmeyen dosyalar gitmez. macOS/Linux/WSL'de `.env`, `*.tfvars`, `id_rsa`, `*.pem` gibi dosyalardaki commit edilmemiş değişiklikler dışarıda bırakılır.
- GitLab/Bitbucket repoları `CCR_FORCE_BUNDLE=1 claude --cloud "..."` ile gönderilebilir, ama oturum sonuçları o remote'a geri push edemez.
- `--cloud` bir Anthropic hesabı ister; Bedrock, Vertex gibi üçüncü taraf sağlayıcılarla çalışmaz. API anahtarıyla giriş yaptıysan `claude auth login` ile claude.ai hesabınla gir.

### Planı yerelde, uygulamayı bulutta yap

```bash
claude --permission-mode plan
# Yaklaşımı birlikte netleştir, planı docs/plan.md olarak kaydet, commit et, push et
claude --cloud "docs/plan.md'deki planı uygula; her adımdan sonra testleri çalıştır"
```

Plan modunda Claude dosyaları okur ve keşif komutları çalıştırır, ama kaynak koda dokunmaz. Kararları sen başındayken verirsin, uzun uygulama işi bulutta otomatik ilerler.

### Paralel görevler

```bash
claude --cloud "auth.spec.ts'deki kararsız testi düzelt"
claude --cloud "API dokümantasyonunu güncelle"
claude --cloud "Logger'ı yapılandırılmış çıktıya geçir"
```

Her biri ayrı VM'de, ayrı dalda çalışır. Görevleri **birbirine dokunmayan** dosya alanlarına bölersen birleştirme çakışması yaşamazsın. Her oturumun aynı kullanım limitinden harcadığını unutma.

### Çalışan oturuma terminalden mesaj göndermek

```bash
claude -p "testler geçince PR aç" --cloud <session-id veya claude.ai/code URL'si>
echo "Sıradaki adım: README'yi güncelle" | claude -p --cloud <session-id>
```

Komut mesajı kuyruğa ekler ve yanıt beklemeden çıkar. Başka bir makineden ya da bir CI betiğinden de kullanılabilir. Makinece okunacak sonuç için `--output-format json` ekle.

## Buluttan terminale: teleport

```bash
claude --teleport                # oturum seçici
claude --teleport <session-id>   # doğrudan
```

- Açık bir Claude Code oturumunun içinden `/teleport` (kısaca `/tp`) ya da `/tasks` → `t`.
- claude.ai/code'da: oturum menüsü → **Open in > Terminal** (yapıştıracağın komutu kopyalar).
- Gereksinimler: temiz git durumu (gerekirse stash önerir), aynı repo (fork değil), oturumun dalının push edilmiş olması, aynı claude.ai hesabı.
- Teleport sonrası terminaldeki çalışma **yerel bir kopyadır**; bulut oturumuna yansımaz. Telefondan yönetmeye devam etmek istersen yerel oturumda `/remote-control` başlat.

Terminaldeki bir oturumu buluta **itmek** CLI'dan mümkün değil; bu yön tek taraflı. Masaüstü uygulamasında **Open in** menüsüyle yapılabiliyor.

## Değişiklikleri incelemek

- Oturumdaki `+42 -18` gibi göstergeye tıkla; diff görünümü açılır.
- Satırlara yorum bırak. Yorumlar bir sonraki mesajınla birlikte Claude'a gider.
- **Compare against** ile farklı bir dala göre karşılaştır.
- Hazır olduğunda PR'ı arayüzden aç.

## Auto-fix: PR'ı Claude takip etsin

Claude, PR'daki CI hatalarına ve inceleme yorumlarına abone olur. Düzeltme netse yapıp push eder, belirsizse sana sorar, gereksiz olayları not edip geçer.

Açmanın yolları:

- Bulutta açılan PR: oturumda CI durum çubuğu → **Auto-fix**
- Terminal: PR'ın dalındayken `/autofix-pr`
- Mobil ya da herhangi bir oturum: PR bağlantısını yapıştırıp "bu PR'ı izle, CI hatalarını ve inceleme yorumlarını düzelt" de

Gereksinim: Claude GitHub App repoda kurulu olmalı.

> ⚠️ Claude inceleme yorumlarına **senin GitHub hesabınla** cevap yazabilir (yanıtlar Claude Code'dan geldiği etiketiyle görünür). Repoda yorumla tetiklenen otomasyon (Atlantis, Terraform Cloud, `issue_comment` ile çalışan GitHub Actions) varsa Auto-fix'i açmadan önce bunu değerlendir.

Taban dal ilerleyip merge çakışması oluştuğunda GitHub bunun için olay göndermez; Claude'a "rebase et" demen gerekir.

## Oturumları yönetmek

- **Paylaşma:** Pro/Max'te Private ve Public, Team/Enterprise'da Private ve Team seçenekleri var. Public, claude.ai'a giriş yapmış herkesin görebilmesi demek. Paylaşmadan önce oturumda özel kod ya da gizli bilgi olup olmadığına bak.
- **Arşivleme:** kenar çubuğunda oturumun üzerine gel → arşiv simgesi. Filtreyle yeniden görülebilir.
- **Silme:** kalıcıdır, geri alınamaz.
- **Kuyruktaki mesajı geri almak:** Claude çalışırken gönderdiğin mesaj henüz okunmadıysa ✕ ile geri alabilirsin.

## Daha büyük ölçek

| Araç | Ne zaman |
|---|---|
| [Projects](https://code.claude.com/docs/en/claude-projects) | Tek bir konuşmada Claude'un birden çok bulut oturumunu başlatıp takip etmesi |
| [Routines](https://code.claude.com/docs/en/routines) | Zamanlanmış, API ile ya da GitHub olaylarıyla tetiklenen çalıştırmalar |
| [Remote Control](https://code.claude.com/docs/en/remote-control) | Kendi makinende çalışan oturumu telefondan ya da tarayıcıdan yönetmek (yerel dosya, özel ağ, büyük donanım) |
| [Ultrareview](https://code.claude.com/docs/en/ultrareview) | Bulut ortamında çok ajanlı derin kod incelemesi |

---

Kaynak: [Use Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web)
