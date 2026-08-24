# Kervan Market Mal Kabul — Web/PWA

Tam saha kullanımı için web tabanlı mal kabul sistemi. Masaüstünde yönetim paneli, telefonda responsive saha ekranı olarak çalışır.

## Hazır modüller
- Yönetici / personel PIN girişi (ilk kullanıcı: admin / 1234)
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
- PIN: `1234`

## Supabase
1. Yeni bir Supabase projesi oluşturun.
2. SQL Editor içinde `supabase/schema.sql` dosyasını çalıştırın.
3. Authentication bölümünden bir e-posta/şifre kullanıcısı oluşturun.
4. Uygulama > Ayarlar ekranında Project URL, Publishable/Anon Key, e-posta ve şifreyi girin.
5. `Şimdi Senkronize Et` butonuna basın.

Tarayıcıya **service_role / secret key koymayın**. Yalnızca publishable/anon key kullanılmalıdır.

## Vercel
Bu klasör static olarak deploy edilebilir. Kamera için production adresi HTTPS olmalıdır.

## Offline davranışı
Uygulama verileri IndexedDB'de tutulur. İnternet yokken mal kabul yapılabilir. Bulut ayarı yapılmışsa internet geri geldiğinde senkronizasyon denenir.

## APK'ya geçiş
Bu PWA daha sonra Capacitor ile Android APK kabuğuna alınabilir. Veri modeli ve iş akışları aynı kalır.
