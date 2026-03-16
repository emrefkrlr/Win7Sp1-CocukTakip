Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$iconPath = "C:\CocukTakip\logo-128x128.ico"

# --- FONKSİYONLAR ---

function Get-Config { 
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json 
    }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Set-Content $configPath 
}

# Görev Yöneticisi Kontrolü (1: Engelle, 0: Aç)
function Set-TaskManager ($v) {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $path)) { New-Item -Path $path -Force }
    Set-ItemProperty -Path $path -Name "DisableTaskMgr" -Value $v
}

# Şifre Doğrulama (Karmaşık metin içinde ana şifre arama)
function Verify-Pass ($inputStr) {
    $cfg = Get-Config
    if ($inputStr -eq $cfg.AdminSifre) { return "ADMIN" }
    if ($inputStr -like "*$($cfg.AnaSifre)*") { return "USER" }
    return "FAIL"
}

# --- ANA EKRAN (KİLİT) ---
function Show-LockScreen {
    Set-TaskManager 1
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Sistem Kilitli"
    $form.WindowState = "Maximized"
    $form.FormBorderStyle = "None"
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45) # Koyu şık lacivert

    # Uygulama İkonunu Form'a Ekle
    if (Test-Path $iconPath) {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
        
        # Ekranın ortasına logoyu yerleştir
        $logoBox = New-Object System.Windows.Forms.PictureBox
        $logoBox.Image = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath).ToBitmap()
        $logoBox.SizeMode = "StretchImage"
        $logoBox.Width = 120
        $logoBox.Height = 120
        $logoBox.Left = ($form.Width / 2) - 60
        $logoBox.Top = ($form.Height / 2) - 220
        $form.Controls.Add($logoBox)
    }

    # Bilgi Metni
    $lbl = New-Object System.Windows.Forms.Label
    $activeChild = (Get-Config).AktifCocuk
    $lbl.Text = "SÜRE DOLDU!`nSIRADAKİ: $($activeChild.ToUpper())"
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.Width = $form.Width
    $lbl.Height = 150
    $lbl.Top = ($form.Height / 2) - 80
    $form.Controls.Add($lbl)
    
    # Şifre Giriş Kutusu
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"
    $txt.Width = 350
    $txt.Height = 40
    $txt.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txt.Left = ($form.Width/2 - 175)
    $txt.Top = ($form.Height/2 + 100)
    $form.Controls.Add($txt)
    
    # Giriş Butonu
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "SİSTEMİ AÇ"
    $btn.Width = 350
    $btn.Height = 50
    $btn.FlatStyle = "Flat"
    $btn.ForeColor = "White"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 250)
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $btn.Top = $txt.Bottom + 20
    $btn.Left = $txt.Left

    $btn.Add_Click({
        $res = Verify-Pass $txt.Text
        if ($res -ne "FAIL") {
            $c = Get-Config
            $c.SistemKilitli = $false
            Save-Config $c
            if ($res -eq "ADMIN") { Set-TaskManager 0 } # Admin her şeyi açar
            $form.Close()
        } else { 
            [System.Windows.Forms.MessageBox]::Show("Hatalı Şifre!") 
            $txt.Clear()
        }
    })
    $form.Controls.Add($btn)
    $form.ShowDialog()
}

# --- KÜÇÜK ZAMANLAYICI PANELİ ---
function Show-TimerPanel {
    $timerForm = New-Object System.Windows.Forms.Form
    $timerForm.Text = "Süre"
    $timerForm.Size = "220,130"
    $timerForm.StartPosition = "Manual"
    $timerForm.Location = New-Object System.Drawing.Point(20, 20)
    $timerForm.FormBorderStyle = "None"
    $timerForm.TopMost = $true
    $timerForm.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

    if (Test-Path $iconPath) { $timerForm.Icon = New-Object System.Drawing.Icon($iconPath) }

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"
    $info.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $info.Dock = "Top"
    $info.Height = 60
    $info.TextAlign = "MiddleCenter"
    
    $btnPause = New-Object System.Windows.Forms.Button
    $btnPause.Text = "YEMEĞE GİDİYORUM (DURDUR)"
    $btnPause.Dock = "Bottom"
    $btnPause.Height = 45
    $btnPause.FlatStyle = "Flat"
    $btnPause.BackColor = [System.Drawing.Color]::DarkOrange
    $btnPause.ForeColor = "White"
    $btnPause.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    $btnPause.Add_Click({
        $c = Get-Config
        $c.SistemKilitli = $true
        Save-Config $c
        $timerForm.Close()
    })

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        $c = Get-Config
        $active = $c.AktifCocuk
        $key = if($active -eq "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        
        # Saniye düşür
        $c.$key -= 1
        
        # Gece saati kontrolü
        if ((Get-Date -Format "HH:mm") -ge $c.LastHour) {
            $c.SistemKilitli = $true; Save-Config $c; $timerForm.Close()
        }

        # Süre bitti mi?
        if ($c.$key -le 0) {
            $c.$key = 3600 # Yeni tur için 1 saat ver
            $c.AktifCocuk = if($active -eq "Mirza") {"Yagiz"} else {"Mirza"}
            $c.SistemKilitli = $true; Save-Config $c
            $timerForm.Close()
        }
        
        Save-Config $c
        $ts = [TimeSpan]::FromSeconds($c.$key)
        $info.Text = "$($active.ToUpper())`nKalan: $($ts.Minutes) dk $($ts.Seconds) sn"
    })

    $timerForm.Controls.AddRange(@($info, $btnPause))
    $timer.Start()
    $timerForm.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    try {
        $c = Get-Config
        if ($c.SistemKilitli) {
            Show-LockScreen
        } else {
            Show-TimerPanel
        }
    } catch {
        # Hata durumunda döngü kırılmasın diye
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 1
}