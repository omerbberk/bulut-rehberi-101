# Bulut görevi şablonu

Aşağıdaki bloğu kopyala, köşeli parantezleri doldur ve claude.ai/code'a yapıştır ya da `claude --cloud "..."` ile gönder.

```text
Amaç: [Ne değişecek? Tek cümle.]
Neden: [Kullanıcıya etkisi ya da issue bağlantısı]

Bağlam:
- İlgili dosyalar: [src/..., tests/...]
- Kısıtlar: [ör. public API değişmesin, yeni bağımlılık ekleme]

Bitti sayılması için:
- [test komutu] geçiyor
- [lint / tip kontrolü komutu] temiz
- [Yeni davranış için test eklendi]

Teslim:
- Dal: claude/[kisa-ad]
- Her anlamlı adımda commit et ve push et
- Bitince PR aç. Açıklamada ne değişti, neden, nasıl test edildi olsun

Önce bana sor: [ör. veritabanı şeması değişecekse, yeni bağımlılık gerekiyorsa]
```

## İyi ve zayıf örnek

**İyi**

> `src/billing/invoice.ts` içinde KDV tutarı yarım kuruşta (0,005) yanlış yöne yuvarlanıyor (#412). Banker's rounding yerine half-up kullan. Sınır değerler için test ekle. `npm test -- billing` ve `npm run typecheck` geçsin. `claude/kdv-yuvarlama` dalında çalış, bitince PR aç.

**Zayıf**

> Faturalardaki hatayı düzelt.

Neden zayıf: hangi hata olduğu, nerede olduğu ve nasıl doğrulanacağı belli değil. Claude tahmin etmek zorunda kalır. Bulut oturumunda başında olmadığın için yanlış tahmin pahalıya gelir.

## Paralel görevleri bölmek

Birden çok bulut oturumu açacaksan görevleri **dosya alanına göre** böl:

```bash
claude --cloud "Sadece src/api/ altında çalış: /users uç noktasına sayfalama ekle"
claude --cloud "Sadece src/web/ altında çalış: kullanıcı listesine sayfalama arayüzü ekle"
claude --cloud "Sadece docs/ altında çalış: sayfalama parametrelerini belgele"
```

Aynı dosyalara dokunan paralel oturumlar birleştirme çakışması üretir. Her oturum aynı kullanım limitinden harcar.

## Uzun görevler için ek satırlar

```text
- Her ana adımdan sonra commit + push et; VM boşta kalırsa duraklatılabilir.
- Çok uzun bir komut gerekirse arka planda çalıştır ve çıktısını dosyaya yaz.
- Bir şey engellenirse (ağ 403, eksik araç) uydurma; neyin eksik olduğunu yaz ve kalan işe devam et.
```
