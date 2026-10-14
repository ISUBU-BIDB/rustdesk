# ISUBU-BIDB RustDesk

Resmi RustDesk sürümleri + ISUBU-BIDB ayarları. `isubu` dalı = upstream tag + **tek** yama commit'i.

`isubu/patch.sh` (derleme sırasında, `config.env` değerleriyle):

1. ID sunucusu ve key derlemeye gömülür (`hbb_common/src/config.rs`).
2. Güncelleme kontrolü `api.rustdesk.com` yerine panele sorar (`hbb_common/src/lib.rs`).
3. "Update" yalnızca bu reponun release varlıklarını indirir (`src/updater.rs`), changelog linki bu repoya gider.
4. "Download" bidbdestek indirme sayfasını açar (flutter + sciter).
5. İlk açılışta `custom-rendezvous-server` ve `key` config'e yazılır (`src/core_main.rs`).
   Kullanıcı başka bir sunucu girmişse dokunulmaz. Resmi sürüme geçilse bile ayar korunur.

Desen bulunamazsa script hata verir; derleme yamasız çıkmaz. Lokal deneme:

```bash
git submodule update --init libs/hbb_common
bash isubu/patch.sh && git diff && git -C libs/hbb_common diff
git checkout -- . && git -C libs/hbb_common checkout -- .
```

## Yayın akışı

- `isubu-sync.yml` (her gün + elle): rustdesk/rustdesk son release'i burada yoksa
  `isubu-<tag>` = `<tag>` + yama commit'i oluşturur, push eder ve `isubu-release.yml`'i başlatır.
  Çakışmada job başarısız olur ve issue açılır.
- `isubu-release.yml` (elle: dal seç, `tag` gir): release'i prerelease olarak açar,
  `flutter-build.yml`'i `upload-tag=<tag>` ile çalıştırır, hepsi başarılıysa yayınlar (latest).
  Bazı derlemeler başarısız olduysa `publish_only` ile sadece yayınlanabilir.
- Panel (`https://bidbdestek.isparta.edu.tr/api/version/latest`) son yayınlanmış release'i döner.
  İstemcideki güncelleme kartı yalnızca burada daha yeni bir sürüm varsa görünür.

## Kurulum (bir kez)

- Repo varsayılan dalı: `isubu` (zamanlanmış workflow'lar yalnızca varsayılan dalda çalışır).
- Actions sekmesinden workflow'ları etkinleştirin.
- Secret `SYNC_PAT`: `repo` + `workflow` yetkili PAT (fine-grained: Contents + Workflows yazma).
- İsteğe bağlı: Settings → Features → Issues (çakışma bildirimi için).

## Yeni sürümde yama elle taşınırsa

```bash
git fetch upstream --tags
git switch -c isubu-X.Y.Z X.Y.Z
git cherry-pick isubu            # çakışmaları çöz
bash isubu/patch.sh              # dene, sonra geri al
git branch -f isubu HEAD && git push -f origin isubu isubu-X.Y.Z
```
