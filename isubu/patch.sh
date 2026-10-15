#!/usr/bin/env bash
# ISUBU-BIDB yamaları. Derleme öncesi, depo kökünde ve submodule'ler çekilmişken çalışır:
#   bash isubu/patch.sh
#
# hbb_common submodule olduğu için yamalar commit'lenmez, her derlemede uygulanır.
# Her değişiklik grep ile doğrulanır: yeni upstream sürümünde desen değişmişse script
# hata verir, derleme yamasız devam etmez. Tekrar çalıştırmak güvenlidir.
#
# Linux/macOS/Windows (Git Bash) runner'larında çalışsın diye sed yerine perl kullanılır.
# Windows runner'ında dosyalar CRLF ile çekilir; çok satırlı desenler \r?\n kullanır.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
# shellcheck source=isubu/config.env
. isubu/config.env
set +a
ISUBU_OWNER="${ISUBU_REPO%%/*}"
ISUBU_REPO_NAME="${ISUBU_REPO##*/}"
export ISUBU_OWNER ISUBU_REPO_NAME

fail() { echo "isubu/patch.sh: $*" >&2; exit 1; }

# replace <dosya> <perl ifadesi> <sonrasında bulunması gereken sabit metin>
replace() {
    local file=$1 expr=$2 expect=$3
    [ -f "$file" ] || fail "$file bulunamadı (submodule çekildi mi?)"
    perl -0pi -e "$expr" "$file"
    grep -qF -- "$expect" "$file" || fail "$file: yama uygulanamadı, beklenen: $expect"
    echo "ok  $file"
}

# 1. Gömülü ID sunucusu ve key
replace libs/hbb_common/src/config.rs \
    's/pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[.*?\];/pub const RENDEZVOUS_SERVERS: &[&str] = &["$ENV{ISUBU_HOST}"];/' \
    "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"$ISUBU_HOST\"];"
replace libs/hbb_common/src/config.rs \
    's/pub const RS_PUB_KEY: &str = ".*?";/pub const RS_PUB_KEY: &str = "$ENV{ISUBU_KEY}";/' \
    "pub const RS_PUB_KEY: &str = \"$ISUBU_KEY\";"

# 2. Güncelleme kontrolü panele sorulur
replace libs/hbb_common/src/lib.rs \
    's#"https://api\.rustdesk\.com/version/latest"#"$ENV{ISUBU_VERSION_URL}"#' \
    "const URL: &str = \"$ISUBU_VERSION_URL\";"

# 3. "Update" düğmesi yalnızca ISUBU release varlıklarını indirir
replace src/updater.rs \
    's/if owner != "rustdesk"(\r?\n\s*)\|\| repo != "rustdesk"/if owner != "$ENV{ISUBU_OWNER}"$1|| repo != "$ENV{ISUBU_REPO_NAME}"/' \
    "if owner != \"$ISUBU_OWNER\""
# updater birim testindeki kabul edilen örnek URL
replace src/updater.rs \
    's#https://github\.com/rustdesk/rustdesk/releases/download/1\.4\.0/#https://github.com/$ENV{ISUBU_REPO}/releases/download/1.4.0/#' \
    "https://github.com/$ISUBU_REPO/releases/download/1.4.0/"
# Sürüm notu linki
replace flutter/lib/desktop/pages/desktop_home_page.dart \
    's#https://github\.com/rustdesk/rustdesk/releases/tag/#https://github.com/$ENV{ISUBU_REPO}/releases/tag/#g' \
    "https://github.com/$ISUBU_REPO/releases/tag/"

# 4. "Download" düğmesi bidbdestek indirme sayfasını açar
for f in flutter/lib/desktop/pages/desktop_home_page.dart flutter/lib/mobile/pages/connection_page.dart; do
    replace "$f" \
        's#https://rustdesk\.com/download\b#$ENV{ISUBU_DOWNLOAD_PAGE}#g' \
        "'$ISUBU_DOWNLOAD_PAGE'"
done
# Sciter arayüzü (Windows sciter derlemesi)
replace src/ui/index.tis \
    's#https://rustdesk\.com/download\b#$ENV{ISUBU_DOWNLOAD_PAGE}#g' \
    "open_url(\"$ISUBU_DOWNLOAD_PAGE\")"

# 5. ID sunucusu config'e (RustDesk2.toml) de yazılır; resmi sürüme geçilse bile korunur.
#    Kullanıcı başka bir sunucu girmişse dokunulmaz.
if ! grep -qF 'ISUBU: kalıcı sunucu ayarı' src/core_main.rs; then
    perl -0pi -e 's/(pub fn core_main\(\) -> Option<Vec<String>> \{\r?\n(?:.*\n)*?    crate::load_custom_client\(\);\r?\n)/$1    \/\/ ISUBU: kalıcı sunucu ayarı\n    if config::Config::get_option("custom-rendezvous-server").is_empty() {\n        config::Config::set_option("custom-rendezvous-server".to_owned(), "$ENV{ISUBU_HOST}".to_owned());\n        if config::Config::get_option("key").is_empty() {\n            config::Config::set_option("key".to_owned(), "$ENV{ISUBU_KEY}".to_owned());\n        }\n    }\n/' src/core_main.rs
fi
grep -qF "config::Config::set_option(\"custom-rendezvous-server\".to_owned(), \"$ISUBU_HOST\".to_owned());" src/core_main.rs \
    || fail "src/core_main.rs: kalıcı sunucu ayarı eklenemedi"
echo "ok  src/core_main.rs"

# Yorum dışında resmi güncelleme/indirme adresi kalmamalı
if grep -rnE 'api\.rustdesk\.com/version|rustdesk\.com/download\b' libs/hbb_common/src src flutter/lib 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*//'; then
    fail "yukarıdaki resmi adresler yamalanmadı"
fi
echo "isubu/patch.sh: tüm yamalar uygulandı"
