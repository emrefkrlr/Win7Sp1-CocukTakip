# 1. Adım: Kütüphaneleri Zorla Yükle
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    $_.Exception.Message | Out-File "C:\CocukTakip\hata_log.txt" -Append
    [System.Windows.Forms.MessageBox]::Show("Kutuphaneler yuklenemedi!")
}

$configPath = "C:\CocukTakip\config.json"
$iconPath = "C:\CocukTakip\logo-128x128.ico"

# --- FONKSİYONLAR ---

function Get-Config { 
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json 
    } else {
        [System.Windows.Forms.MessageBox]::Show("Config dosyasi bulunamadi!")
    }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Set-Content $configPath 
}

function Set-TaskManager ($v) {
    try {
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        if (!(Test-Path $path)) { New-Item -Path $path -Force }
        Set-ItemProperty -Path $path -Name "DisableTaskMgr" -Value $v
    } catch {}
}

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
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)

    # İkon ve Logo Yükleme (Hata Payı Bırakarak)
    if (Test-Path $iconPath) {
        try {
            $form.Icon = New-Object System.Drawing.Icon($iconPath)
            $logoBox = New-Object System.Windows.Forms.PictureBox
            # ExtractAssociatedIcon yerine direkt Bitmap deniyoruz (Daha güvenli)
            $bmp = [System.Drawing.Icon]::new($iconPath).ToBitmap()
            $logoBox.Image = $bmp
            $logoBox.SizeMode = "StretchImage"
            $logoBox.Width = 120
            $logoBox.Height = 120
            $logoBox.Left = ($form.Width / 2) - 60
            $logoBox.Top = ($form.Height / 2) - 220
            $form.Controls.Add($logoBox)
        } catch {
            "Ikon yukleme hatasi: $($_.Exception.Message)" | Out-File "C:\CocukTakip\hata_log.txt" -Append
        }
    }

    $lbl = New-Object System.Windows.Forms.Label
    $cfg = Get-Config
    $activeChild = $cfg.AktifCocuk
    $lbl.Text = "SURE DOLDU!`nSIRADAKI: " + $activeChild.ToUpper()
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.Width = $form.Width
    $lbl.Height = 150
    $lbl.Top = ($form.Height / 2) - 80
    $form.Controls.Add($lbl)
    
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"
    $txt.Width = 350
    $txt.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txt.Left = ($form.Width/2 - 175)
    $txt.Top = ($form.Height/2 + 100)
    $form.Controls.Add($txt)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "SISTEMI AC"
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
            if ($res -eq "ADMIN") { Set-TaskManager 0 }
            $form.Close()
        } else { 
            [System.Windows.Forms.MessageBox]::Show("Hatali Sifre!") 
            $txt.Clear()
        }
    })
    $form.Controls.Add($btn)
    $form.ShowDialog()
}

# --- KÜÇÜK ZAMANLAYICI PANELİ ---
function Show-TimerPanel {
    $timerForm = New-Object System.Windows.Forms.Form
    $timerForm.Size = "220,130"
    $timerForm.StartPosition = "Manual"
    $timerForm.Location = New-Object System.Drawing.Point(20, 20)
    $timerForm.FormBorderStyle = "None"
    $timerForm.TopMost = $true
    $timerForm.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"
    $info.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $info.Dock = "Top"
    $info.Height = 60
    $info.TextAlign = "MiddleCenter"
    
    $btnPause = New-Object System.Windows.Forms.Button
    $btnPause.Text = "DURDUR (YEMEK)"
    $btnPause.Dock = "Bottom"
    $btnPause.Height = 45
    $btnPause.BackColor = [System.Drawing.Color]::DarkOrange
    $btnPause.ForeColor = "White"

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
        $c.$key -= 1
        
        if ((Get-Date -Format "HH:mm") -ge $c.LastHour) {
            $c.SistemKilitli = $true; Save-Config $c; $timerForm.Close()
        }

        if ($c.$key -le 0) {
            $c.$key = 3600
            $c.AktifCocuk = if($active -eq "Mirza") {"Yagiz"} else {"Mirza"}
            $c.SistemKilitli = $true; Save-Config $c
            $timerForm.Close()
        }
        
        Save-Config $c
        $ts = [TimeSpan]::FromSeconds($c.$key)
        $info.Text = $active.ToUpper() + "`nKalan: " + $ts.Minutes + " dk " + $ts.Seconds + " sn"
    })

    $timerForm.Controls.AddRange(@($info, $btnPause))
    $timer.Start()
    $timerForm.ShowDialog()
}

# --- ANA DÖNGÜ ---
# Başlangıç Mesajı (Kodun çalıştığını teyit etmek için)
# [System.Windows.Forms.MessageBox]::Show("Sistem Baslatiliyor...") 

while($true) {
    try {
        $c = Get-Config
        if ($c.SistemKilitli -eq $true) {
            Show-LockScreen
        } else {
            Show-TimerPanel
        }
    } catch {
        $_.Exception.Message | Out-File "C:\CocukTakip\hata_log.txt" -Append
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 1
}