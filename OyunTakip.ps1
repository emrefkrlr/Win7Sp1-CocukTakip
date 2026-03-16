# 1. İlk olarak her şeyi bir 'Try-Catch' içine alalım
try {
    # STA Modu Kontrolü ve Form Yükleme
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Ekrana basit bir mesaj basalım (Konsolda görünmeli)
    Write-Host "--- SISTEM BASLATILIYOR ---" -ForegroundColor Cyan

    $configPath = "C:\CocukTakip\config.json"
    
    # Config dosyasını oku
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath | ConvertFrom-Json
        Write-Host "Config okundu. Aktif Cocuk: $($cfg.AktifCocuk)" -ForegroundColor Green
    } else {
        throw "Config dosyasi bulunamadi!"
    }

    # BASIT BIR TEST FORMU (Sadece ekranın açılıp açılmadığını görmek için)
    $testForm = New-Object System.Windows.Forms.Form
    $testForm.Text = "TEST EKRANI"
    $testForm.Size = New-Object System.Drawing.Size(300,200)
    $testForm.StartPosition = "CenterScreen"
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "TIKLA"
    $btn.Dock = "Fill"
    $btn.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Form calisiyor!"); $testForm.Close() })
    
    $testForm.Controls.Add($btn)
    
    Write-Host "Form gosteriliyor... (Eger ekran gelmiyorsa burada takilmistir)" -ForegroundColor Yellow
    $testForm.ShowDialog()

} catch {
    # Hata varsa hem ekrana yaz hem dosyaya kaydet
    $hata = "HATA: " + $_.Exception.Message
    Write-Host $hata -ForegroundColor Red
    $hata | Out-File "C:\CocukTakip\KRITIK_HATA.txt"
    Read-Host "Devam etmek icin Enter'a basin..."
}