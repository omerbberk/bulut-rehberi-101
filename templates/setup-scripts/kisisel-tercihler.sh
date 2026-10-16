#!/bin/bash
# Kişisel tercihlerini paylaşılan repoya koymadan bulut oturumlarına taşı.
#
# Senin ~/.claude/CLAUDE.md dosyan buluta otomatik gitmez. Bu betik onu VM'de oluşturur;
# Claude Code bu dosyayı kullanıcı talimatı olarak yükler.
#
# YALNIZCA KENDİ ortamında kullan. Kuruluşla paylaşılan bir ortama koyma:
# ortamın setup script'ini o ortamı kullanan herkes okuyabilir.
#
# Doğrulama: yeni bir oturumda /context çalıştır; "Memory files" altında
# /root/.claude/CLAUDE.md görünmeli.

mkdir -p ~/.claude
cat >~/.claude/CLAUDE.md <<'EOF'
# Kişisel tercihler
- Bana Türkçe cevap ver; kod, commit mesajları ve PR metinleri İngilizce olsun.
- Conventional Commits kullan (feat:, fix:, docs:, refactor:, test:, chore:).
- Her anlamlı adımdan sonra commit et ve push et.
- Emin olmadığın tasarım kararlarında önce bana sor.
EOF

exit 0
