# ISUBU-BIDB RustDesk

Resmi RustDesk sürümleri + ISUBU-BIDB ayarları. `isubu` dalı = upstream tag + ISUBU yama commit'leri.

Amaç: masaüstü uygulamasındaki güncelleme kartı kullanıcıları resmi siteye/sürüme
yönlendirmesin; güncellemeler yalnızca bu repodan ve bidbdestek sayfasından gelsin.

`isubu/patch.sh` (derleme sırasında, `config.env` değerleriyle):

1. ID sunucusu ve key derlemeye gömülür (`hbb_common/src/config.rs`).
2. Güncelleme kontrolü `api.rustdesk.com` yerine panele sorar (`hbb_common/src/lib.rs`).
3. "Update" yalnızca bu reponun release varlıklarını indirir (`src/updater.rs`), changelog linki bu repoya gider.
4. "Download" bidbdestek indirme sayfasını açar (flutter + sciter).
5. İlk açılışta `custom-rendezvous-server` ve `key` config'e yazılır (`src/core_main.rs`).
   Kullanıcı başka bir sunucu girmişse dokunulmaz. Resmi sürüme geçilse bile ayar korunur.
6. Panel API'si (heartbeat, bağlantı kayıtları) `http://<ID sunucusu>:21114` yerine `ISUBU_API_URL` (HTTPS 443) adresine gider; 21114 kampüs dışından erişilemez (`src/common.rs`).

Desen bulunamazsa script hata verir; derleme yamasız çıkmaz. Lokal deneme:

```bash
git submodule update --init libs/hbb_common
bash isubu/patch.sh && git diff && git -C libs/hbb_common diff
git checkout -- . && git -C libs/hbb_common checkout -- .
```

## Yayın akışı

- `isubu-release.yml` (elle: Actions → ISUBU Release → Run workflow, dal seç, `tag` gir):
  release'i prerelease olarak açar, `flutter-build.yml`'i `upload-tag=<tag>` ile çalıştırır,
  hepsi başarılıysa yayınlar (latest). Bazı derlemeler başarısız olduysa `publish_only`
  ile derlemeden sadece yayınlanabilir.
- Panel (`https://bidbdestek.isparta.edu.tr/api/version/latest`) son yayınlanmış release'i döner.
  İstemcideki güncelleme kartı yalnızca burada daha yeni bir sürüm varsa görünür.
- `isubu-sync.yml` elle çalışır ve `SYNC_PAT` secret'ı ister (şu an tanımlı değil);
  yeni sürüm aşağıdaki gibi lokalde taşınır.

## Yeni sürüm (ör. 1.5.1)

```bash
git fetch upstream --no-tags refs/tags/1.5.1:refs/tags/1.5.1
BASE=$(git merge-base isubu 1.5.1)
git switch -c isubu-1.5.1 1.5.1
git cherry-pick "$BASE..isubu"   # çakışma olursa çöz, git cherry-pick --continue
git submodule update --init libs/hbb_common
bash isubu/patch.sh && git diff --stat   # hatasız bitmeli; sonra geri al:
git checkout -- . && git -C libs/hbb_common checkout -- .
git push origin isubu-1.5.1
git branch -f isubu isubu-1.5.1 && git push -f origin isubu
```

Ardından Actions → ISUBU Release → Run workflow: dal `isubu-1.5.1`, tag `1.5.1`.

## Kurulum (bir kez)

- Repo varsayılan dalı: `isubu`.
- Actions sekmesinden workflow'ları etkinleştirin.
- İsteğe bağlı secret `SYNC_PAT` (`repo` + `workflow` yetkili PAT): yalnızca `isubu-sync.yml` için.
- İsteğe bağlı: Settings → Features → Issues (çakışma bildirimi için).
