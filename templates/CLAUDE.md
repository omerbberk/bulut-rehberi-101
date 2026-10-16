# [Proje adı]

[Bir iki cümle: proje ne yapar, ana teknolojiler neler.]

## Komutlar

- Kurulum: `[npm install]` (bulutta oturum başında `scripts/cloud-session-start.sh` otomatik çalıştırır)
- Tüm testler: `[npm test]`
- Tek test dosyası: `[npx vitest run yol/dosya.test.ts]`
- Lint: `[npm run lint]`
- Tip kontrolü: `[npm run typecheck]`
- Derleme: `[npm run build]`

Bir işi bitti saymadan önce test, lint ve tip kontrolünü çalıştır. Hepsi temiz değilse bitti deme; neyin kaldığını yaz.

## Proje yapısı

- `[src/]`: [ne var]
- `[tests/]`: [ne var]

## Kurallar

- Dal adı: `claude/<kisa-aciklama>`
- Commit mesajları: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- PR açıklamasında: ne değişti, neden, nasıl test edildi.
- [Kod stiliyle ilgili linter'ın yakalamadığı kurallar]

## Bulut oturumları

- VM geçicidir: her anlamlı adımdan sonra commit et ve push et.
- Bağımlılıklar oturum başında `scripts/cloud-session-start.sh` ile kurulur. Özet oturumun başında görünür, ayrıntılı log `~/.cache/claude-session-start/` altında.
- [Veritabanı gerekiyorsa: `service postgresql start`]
- [Harici API: `api.example.com` için ortamda network secret tanımlı. İstek kimlik hatası verirse anahtarı arama ya da uydurma; durumu bildir.]
- Ağ isteği proxy'den 403 alırsa aynı isteği tekrar tekrar deneme; hangi alan adının engellendiğini raporla.
- `gh pr` ve `gh issue` bulutta çalışmaz (GraphQL kapalı). Bunların yerine `gh api repos/OWNER/REPO/...` REST çağrılarını kullan.

## Dokunma

- [`migrations/` altındaki eski dosyaları değiştirme; yeni migration ekle.]
- `.env*` dosyalarını ve gizli bilgileri commit etme.
