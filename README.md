# Kervan Mal Kabul Web / PWA

İlk MVP: build gerektirmeyen statik PWA. Vercel, Netlify veya herhangi bir HTTPS web sunucusuna doğrudan yüklenebilir.

## Çalışan özellikler
- Ana ekran
- IndexedDB yerel ürün ve mal kabul veritabanı
- AKINSOFT CSV/XLSX içe aktarma
- Barkoddan ürün bulma
- Android Chrome BarcodeDetector kamera desteği + manuel barkod yedeği
- ADET / KOLİ / KUTU dönüşümü
- Birim bilgisi eksik üründe koli/kutu içi tanımlama
- Tanımsız barkodu yeni ürün olarak ekleme
- Aynı ürün tekrar okutulunca satır birleştirme
- Taslak mal kabulü cihazda anlık saklama
- Mal kabul tamamlama ve geçmiş
- PWA/service worker ile temel offline çalışma

## Lokal çalıştırma
Service Worker ve kamera için dosyayı çift tıklamak yerine localhost kullanın:

```bash
python -m http.server 8080
```

Sonra http://localhost:8080 açın.

## Deploy
Bu klasörü Vercel'e statik proje olarak yükleyin. Kamera üretimde HTTPS ister.

## Sonraki faz
- Supabase Auth ve merkezi senkronizasyon
- Yönetici/personel rolleri
- Raporlar ve Excel dışa aktarma
- Audit log
- Tedarikçi yönetimi
- Çakışma/senkronizasyon kuyruğu
