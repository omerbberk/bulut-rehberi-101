# 05 · Verimlilik: daha az bekle, daha az harca

## 1. Limitleri bil

Bulut oturumları, hesabındaki diğer tüm Claude ve Claude Code kullanımıyla aynı limiti paylaşır. Paralel çalışan her oturum, limitinden orantılı pay alır.

- Paralelliği **gerçekten bağımsız** işler için kullan.
- Basit ya da keşif ağırlıklı işlerde daha hafif bir model ya da daha düşük efor seç. Bulutta bu komutlar seçici açmaz, değeri argüman olarak verirsin: `/model sonnet`, `/effort low`.
- Emin değilsen küçük bir görevle başla, sonucu görünce büyüt.

## 2. Açılışı hızlandır

| Sorun | Çözüm |
|---|---|
| Her oturum araçları baştan kuruyor | Kurulumu setup script'e taşı ve 5 dakikanın altında tut; böylece önbelleğe alınır |
| Önbellek oluşmuyor | Setup script'i paralelleştir (`&` + PID'lerle `wait`); büyük indirmeleri hook'ta arka plana al |
| `npm install` her oturumda baştan çalışıyor | Hook'ta kilit dosyası hash'iyle atla: [şablon](../templates/scripts/cloud-session-start.sh) |
| Docker imajları yavaş iniyor | Setup script'te `docker pull` yap; imajlar önbellekte kalır: [şablon](../templates/setup-scripts/docker-imajlari.sh) |

## 3. Görevi iyi tarif et

Bulut oturumu en iyi, Claude'un kendi başına **bitirip doğrulayabildiği** görevlerde çalışır. İyi bir görevde şunlar olur:

- **Amaç:** ne değişecek ve neden
- **Bağlam:** ilgili dosyalar, issue bağlantısı, kısıtlar
- **Bitti kriteri:** hangi komutlar geçmeli (`npm test`, `ruff check .`)
- **Teslim:** dal adı, PR açılıp açılmayacağı, açıklamada ne olacağı
- **Sınırlar:** dokunulmayacak yerler, önce sorulması gereken kararlar

Şablon: [templates/gorev-sablonu.md](../templates/gorev-sablonu.md)

## 4. CLAUDE.md'yi bulut için yaz

Her oturum sıfırdan başlar ve Claude projeyi CLAUDE.md'den öğrenir. İçinde şunlar mutlaka olsun:

- Kurulum, test, lint ve derleme komutlarının tam hali
- Hangi servislerin gerektiği ve nasıl başlatıldığı
- Dal, commit ve PR kuralları
- Bulut için bilinen kısıtlar (ör. "`gh pr` çalışmaz, `gh api` kullan", "X API'si için network secret tanımlı")

Şablon: [templates/CLAUDE.md](../templates/CLAUDE.md)

## 5. Bağlamı yönet

| Komut | Bulutta |
|---|---|
| `/compact [odak]` | Var. Konuşmayı özetler, ör. `/compact test çıktısını koru` |
| `/context` | Var. Bağlamda nelerin yer kapladığını gösterir |
| `/clear` | **Yok.** Kenar çubuğundan yeni oturum aç |

- Otomatik sıkıştırma bulutta, pencere tamamen dolmadan, oturumun belirlediği bir yüzdede tetiklenir.
- Uzun araştırmaları alt ajanlara (subagent) yaptır; ana bağlam hafif kalır. Repodaki `.claude/agents/` tanımları otomatik yüklenir.
- Konu değiştiğinde yeni oturum açmak, uzayan bir oturumu sürdürmekten genellikle daha ucuz ve daha isabetlidir.

## 6. Uzun işler ve zaman aşımları

- Ön planda çalışan bir komut varsayılan olarak 2 dakika, en fazla 10 dakika beklenir. Süreyi aşan komut durdurulmaz, arka plana alınır ve 30 dakika daha çalışabilir (`sleep` ile başlayanlar hariç).
- Uzun derleme ve testler için ortam değişkenleri:

  ```text
  BASH_DEFAULT_TIMEOUT_MS=600000
  BASH_MAX_TIMEOUT_MS=1800000
  ```

  `BASH_DEFAULT_TIMEOUT_MS` 1800000'in üzerine çıkarsa arka plan sınırı da uzar.
- SessionStart hook'u varsayılan olarak 600 saniye sonra iptal edilir; hook tanımında `"timeout"` (saniye) ile değiştir.

## 7. VM'in duraklamasına hazırlıklı ol

- Birkaç dakika etkileşim olmazsa VM duraklatılır, daha uzun süre sonra geri alınabilir. Geri alınınca arka plandaki komutlar, alt ajanlar ve `/loop` kaybolur.
- Uzun işlerde Claude'dan ara sonuçları commit edip push etmesini iste.
- Bir MCP connector aracının onayını ya da MCP girişini beklerken de oturum "boşta" sayılır ve süresi dolabilir. Onay isteyen işleri başında olacağın zamana denk getir.

## 8. Disk ve belleği koru

- Disk ~30 GB'lık bir kota. `node_modules`, `target/`, `.gradle` ve Docker imajları onu hızla doldurur. `no space left on device` görürsen derleme çıktılarını ve önbellekleri sil (`docker system prune -f`, `cargo clean`).
- Bellek ~16 GB. Paralel test işçilerini sınırla (ör. `jest --maxWorkers=2`, pytest-xdist ile `pytest -n 4`).

## 9. Doğru aracı seç

| Durum | En iyi yer |
|---|---|
| Bağımsız, iyi tanımlı, test edilebilir görev | Bulut oturumu |
| Yerel dosya, özel ağ, cihaz ya da büyük derleme gerekiyor | Yerel oturum + Remote Control |
| Düzenli tekrar eden iş (gece raporu, bağımlılık güncellemesi) | Routine |
| Birbirine bağlı çok sayıda görev | Projects |
| PR'ın CI'ını ve inceleme yorumlarını kovalamak | Auto-fix |

---

Kaynaklar: [Use Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web) · [Time limits](https://code.claude.com/docs/en/cloud-environments#time-limits)
