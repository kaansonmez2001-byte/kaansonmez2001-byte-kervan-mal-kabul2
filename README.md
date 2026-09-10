# Kervan Market Mal Kabul — Web/PWA

Tam saha kullanımı için web tabanlı mal kabul sistemi. Masaüstünde yönetim paneli, telefonda responsive saha ekranı olarak çalışır.

## Hazır modüller
- Yönetici / personel PIN girişi (ilk kullanıcı: admin / 1453)
- Responsive sol menülü yönetim paneli
- AKINSOFT Excel / CSV ürün yükleme ve ürün arama
- Barkod kamera okutma (EAN/UPC/Code türleri html5-qrcode desteği kapsamında) + manuel barkod
- ADET / KOLI / KUTU çevrim hesabı
- Birimi eksik ürünü ilk okumada tanımlama ve kalıcı saklama
- Barkodu bilinmeyen ürünü sonradan ekleme + ayrı rapor
- Aynı barkodu aynı birim/çevrimle tekrar okutunca satır birleştirme
- Taslak mal kabul, tamamlanmış mal kabul, geçmiş ve detay
- Yönetici tarafından tamamlanmış satır miktarı değiştirme/silme + audit log
- Tedarikçi yönetimi
- Personel/kullanıcı yönetimi ve rol bazlı menü
- Rapor ekranı
- Excel dışa aktarma
- IndexedDB ile offline veri saklama
- PWA service worker
- Supabase push senkronizasyonu
- Vercel static deployment ayarı

## Çalıştırma
Dosyaları doğrudan çift tıklamak yerine HTTPS veya localhost üzerinden açın:

```bash
python -m http.server 8080
```

http://localhost:8080

Kamera localhost'ta veya HTTPS üzerinde çalışır.

## İlk giriş
- Kullanıcı: `admin`
- PIN: `1453`

## Merkezi personel
Bu sürüm Kervan Mal Kabul Supabase projesine (`gibnvcducxqyrfvrtbub`) bağlıdır.
- Giriş Supabase Auth üzerinden yapılır; rol ve aktiflik `staff` tablosundan okunur.
- Kullanıcı yönetimi `manage-staff` Edge Function içinde mevcut yönetici rolü doğrulanarak yapılır.
- Yeni personellerde varsayılan PIN 1453'tür. Yönetici PIN değiştirebilir; mevcut PIN gösterilmez.
- Yönetici eski kayıtların bulunduğu cihazdan giriş yaptığında eksik yerel kullanıcılar 1453 PIN ile merkeze aktarılır. Mevcut merkezi kullanıcılar ezilmez.
- Hesap listesi yönetim ekranında 20 saniyede bir ve pencereye dönüldüğünde yenilenir.
- Eski cihaz içi oturum giriş yetkisi vermez. Yeni giriş için internet gerekir.
- `supabase/central-staff.sql` mevcut üretim şemasına uygulanmıştır. `schema.sql` eski kurulum örneğidir; mevcut projeye yeniden uygulamayın.
- `supabase/functions/manage-staff/index.ts` üretimde yayımlanmıştır; servis anahtarı yalnızca Edge Function ortamında kullanılır.
- Mal kabul verileri cihaz içinde tutulmaya devam eder; Ayarlar'daki aktarım düğmesi kayıtları merkeze gönderir. Bu sürümde cihazlar arası otomatik paylaşım personel hesaplarını kapsar.

## Vercel
Bu klasör static olarak deploy edilebilir. Kamera için production adresi HTTPS olmalıdır.

## Offline davranışı
Uygulama verileri IndexedDB'de tutulur. İnternet yokken mal kabul yapılabilir. Bulut ayarı yapılmışsa internet geri geldiğinde senkronizasyon denenir.

## APK'ya geçiş
Bu PWA daha sonra Capacitor ile Android APK kabuğuna alınabilir. Veri modeli ve iş akışları aynı kalır.
