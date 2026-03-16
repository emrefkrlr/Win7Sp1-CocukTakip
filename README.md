# 🛡️ Win7Sp1-CocukTakip (Mirza & Yağız)

Bu proje, Windows 7 SP1 (PowerShell 5.1) işletim sistemine sahip bilgisayarlarda çocukların bilgisayar kullanım süresini adil bir şekilde yönetmek için tasarlanmış bir **Akıllı Kilit Sistemi**'dir.

## ✨ Özellikler
* **Çift Profil Desteği:** Mirza ve Yağız için ayrı süre takibi.
* **Gizli Şifre Mantığı:** Uzun bir metin içine gizlenmiş ana şifre ile güvenli giriş.
* **Mola Sistemi:** "Yemeğe Gidiyorum" butonu ile süreyi durdurma ve ekranı kilitleme.
* **Zaman Sınırı (Last Hour):** Belirlenen saatten sonra (Örn: 21:00) bilgisayarın tamamen kilitlenmesi.
* **Güvenlik:** Görev yöneticisinin otomatik devre dışı bırakılması ve kilit ekranının her zaman en üstte kalması.
* **Admin Erişimi:** Ebeveyn için kısıtlamasız giriş şifresi.

## 📂 Dosya Yapısı
Sistemin çalışması için tüm dosyaların `C:\CocukTakip\` klasörü altında bulunması gerekmektedir:
- `OyunTakip.ps1`: Ana uygulama kodu.
- `config.json`: Sürelerin ve şifrelerin tutulduğu ayar dosyası.

## 🚀 Kurulum Adımları

### 1. Dosyaları Hazırlayın
Projeyi `C:\CocukTakip\` klasörüne indirin. `config.json` dosyasındaki şifreleri ve saatleri kendinize göre güncelleyin.

### Adım 2: PowerShell Yetkilerini Tanımlayın
Windows 7 güvenlik nedeniyle dışarıdan gelen scriptlerin çalışmasını engeller. Bunu aşmak için:

1. Başlat menüsüne "PowerShell" yaz.

2. Mavi logoya sağ tıkla ve "Yönetici Olarak Çalıştır" de.

3. Açılan ekrana şu komutu yapıştır ve Enter'a bas:

```PowerShell
Set-ExecutionPolicy RemoteSigned -Force
```
4. Gelen soruya "Y" (Evet) diyerek onayla.

### Adım 3: Görev Zamanlayıcı ile "Kapatılamaz" Yapın

Çocukların bu programı kapatamaması için onu bir Windows servisi gibi arka planda başlatmalıyız:

1. Başlat menüsüne taskschd.msc yaz ve aç.

2. Sağ taraftaki panelden "Görev Oluştur..." (Create Task) seçeneğine tıkla.

3. Genel Sekmesi:

    - İsim: CocukTakip

    - En alttaki "En yüksek ayrıcalıklarla çalıştır" kutucuğunu işaretle. (Bu, şifre ekranının oyunların üstüne çıkmasını sağlar).

4. Tetikleyiciler (Triggers) Sekmesi:

    - "Yeni..." butonuna tıkla.

    - En üstteki listeden "Oturum açıldığında" (At log on) seçeneğini seç ve Tamam de.

5. Eylemler (Actions) Sekmesi:

    - "Yeni..." butonuna tıkla.

    - Program/Script kısmına: powershell.exe yaz.

    - Bağımsız değişkenler ekle kısmına tam olarak şunu yapıştır:
    ```PowerShell
    -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\CocukTakip\OyunTakip.ps1"
    ```
6. Ayarlar (Settings) Sekmesi:

    - "Görevin zaten çalışıyor olması durumunda..." seçeneğinin "Yeni bir örneği başlatma" olduğundan emin ol.

### Adım 4: İlk Çalıştırma ve Test
Kurulum bitti! Bilgisayarı yeniden başlatabilir veya Görev Zamanlayıcı'da oluşturduğun göreve sağ tıklayıp "Çalıştır" diyebilirsin.

## Test Etmek İçin:

- Sistem açıldığında ekran kilitlenecek mi? (İlk başta SistemKilitli: true ise kilitlemeli).

- Çocuklara verdiğin "uzun metinli" şifreyi girince ekran açılıyor mu?

- Küçük zamanlayıcı paneli köşede görünüyor mu?

- Durdur butonuna basınca ekran tekrar kilitleniyor mu?

## Son Kontrol Listesi
- Config Güncelleme: config.json içindeki LastHour (21:00 gibi) ve AnaSifre değerlerini kendi istediğin değerlerle güncelledin mi?

- Admin Şifresi: Kendi özel admin şifreni kimseye söyleme, bu şifre sistemin tüm kısıtlamalarını (Görev Yöneticisi dahil) anında açar.