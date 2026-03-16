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

### 2. PowerShell İzinlerini Açın
Windows PowerShell'i yönetici olarak çalıştırın ve şu komutu girin:
```powershell
Set-ExecutionPolicy RemoteSigned -Force
```

### 3. Otomatik Başlatma (Görev Zamanlayıcı)

Sistemin her açılışta çalışması ve kapatılamaz olması için:

- taskschd.msc (Görev Zamanlayıcı) uygulamasını açın.

- Yeni Görev Oluştur'a tıklayın.

- Genel: Adını CocukTakip koyun. "En yüksek ayrıcalıklarla çalıştır" seçeneğini işaretleyin.

- Tetikleyiciler: "Oturum açıldığında" olarak ayarlayın.

- Eylemler: "Program Başlat"ı seçin.

-- Program/Script: powershell.exe

-- Bağımsız Değişkenler: -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\CocukTakip\OyunTakip.ps1"

- Ayarlar: "Görevin zaten çalışıyor olması durumunda: Yeni bir örneği başlatma" seçeneğini seçin.

## 🛠️ Yapılandırma (config.json)

```JSON
{
    "AnaSifre": "x9395",          // Çocukların şifresindeki gizli anahtar
    "AdminSifre": "Admin123!",   // Sizin tam yetki şifreniz
    "LastHour": "21:00",         // Bilgisayarın kapanacağı saat
    "AktifCocuk": "Mirza",       // Sıradaki çocuk
    "MirzaKalanSaniye": 3600,    // Kalan süreler
    "YagizKalanSaniye": 3600,
    "SistemKilitli": true        // Başlangıç durumu
}
````

---

### 🚀 GitHub'a Gönderme Adımları (VS Code Üzerinden)

Eğer VS Code'da terminal üzerinden bu dosyaları repoya göndermek istersen şu komutları sırasıyla uygulayabilirsin:

1.  **Değişiklikleri ekle:** `git add .`
2.  **Commit oluştur:** `git commit -m "İlk kurulum dosyaları ve README eklendi"`
3.  **Gönder:** `git push origin main` (Veya ana dalın ismi neyse)

---

**Dosyaları GitHub'a başarıyla gönderdikten sonra, diğer bilgisayara geçip kurulumu yapmaya hazır mısın? İstersen son bir kez tüm PowerShell kodunu kontrol edelim.**