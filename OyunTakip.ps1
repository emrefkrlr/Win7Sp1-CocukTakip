Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

# --- API VE YARDIMCI ARAÇLAR ---
$code = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"Win32").Type) { Add-Type -TypeDefinition $code }

function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

function Get-Config { return Get-Content $configPath -Raw | ConvertFrom-Json }
function Save-Config ($obj) { $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force }

# --- ZAMAN KONTROLÜ (HATA GİDERİLMİŞ VERSİYON) ---
function Check-TimePermit {
    $cfg = Get-Config
    $now = (Get-Date).TimeOfDay
    $day = (Get-Date).DayOfWeek
    $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
    $permits = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
    
    foreach ($p in $permits) {
        # Kültür bağımsız saat okuma (08:30 formatı için)
        $bas = [TimeSpan]::Parse($p.Bas)
        $bit = [TimeSpan]::Parse($p.Bit)
        
        if ($now -ge $bas -and $now -lt $bit) { return $true }
    }
    Write-Log "DEBUG" "Giris Reddedildi! Su anki saat: $($now.ToString()). Izin araliginda degil."
    return $false
}

# --- KİLİT EKRANI (MATERIAL YOU STYLE) ---
function Show-LockScreen {
    $cfg = Get-Config
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = "None"; $form.WindowState = "Maximized"
    $form.TopMost = $true; $form.BackColor = [System.Drawing.Color]::FromArgb(26, 44, 38) # Görseldeki koyu yeşil

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    # Saat ve Tarih (Görseldeki sol üst widget tarzı)
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text = Get-Date -Format "HH:mm"
    $lblTime.ForeColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $lblTime.Font = New-Object System.Drawing.Font("Segoe UI Light", 72)
    $lblTime.Size = "$($scrW), 120"; $lblTime.TextAlign = "MiddleCenter"; $lblTime.Top = ($scrH / 2) - 300

    # Kullanıcı Seçim Kartları
    $script:secili = "Mirza"
    $btnStyle = {
        param($btn, $name)
        $btn.Text = $name; $btn.Size = "180,180"; $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0; $btn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $btn.ForeColor = "White"; $btn.Cursor = "Hand"
    }

    $btnM = New-Object System.Windows.Forms.Button; &$btnStyle $btnM "MIRZA"
    $btnM.Left = ($scrW / 2) - 190; $btnM.Top = ($scrH / 2) - 100
    
    $btnY = New-Object System.Windows.Forms.Button; &$btnStyle $btnY "YAĞIZ"
    $btnY.Left = ($scrW / 2) + 10; $btnY.Top = ($scrH / 2) - 100

    $updUI = {
        if ($script:secili -eq "Mirza") { 
            $btnM.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79); $btnY.BackColor = [System.Drawing.Color]::FromArgb(40, 60, 55) 
        } else { 
            $btnY.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79); $btnM.BackColor = [System.Drawing.Color]::FromArgb(40, 60, 55) 
        }
    }
    &$updUI
    $btnM.Add_Click({ $script:secili = "Mirza"; &$updUI })
    $btnY.Add_Click({ $script:secili = "Yağız"; &$updUI })

    # Şifre Kutusu (Yuvartlatılmış illüzyonu için panel içine)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Size = "300,40"; $txt.Font = New-Object System.Drawing.Font("Segoe UI", 18)
    $txt.Left = ($scrW / 2) - 150; $txt.Top = $btnM.Bottom + 40; $txt.TextAlign = "Center"
    $txt.BackColor = [System.Drawing.Color]::FromArgb(168, 229, 193); $txt.BorderStyle = "None"
    
    # Giriş Butonu
    $btnE = New-Object System.Windows.Forms.Button
    $btnE.Text = "KİLİDİ AÇ"; $btnE.Size = "300,50"; $btnE.BackColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $btnE.FlatStyle = "Flat"; $btnE.FlatAppearance.BorderSize = 0; $btnE.ForeColor = [System.Drawing.Color]::Black
    $btnE.Left = $txt.Left; $btnE.Top = $txt.Bottom + 20; $btnE.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    
    $btnE.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close()
        } elseif ($txt.Text.ToLower().Contains($c.AnaSifre.ToLower())) {
            if (Check-TimePermit) {
                $c.SistemKilitli = $false; $c.AdminModu = $false; $c.AktifCocuk = $script:secili; Save-Config $c; $form.Close()
            } else { [System.Windows.Forms.MessageBox]::Show("Şu an kullanım saati dışındasınız!", "Zaman Sınırı") }
        } else { $txt.Text = ""; $txt.PlaceholderText = "Hatalı!" }
    })

    # Alt Bilgilendirme Paneli (Geliştirme 3)
    $day = (Get-Date).DayOfWeek
    $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
    $prm = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
    $txtIzin = "BUGÜNÜN İZİN SAATLERİ: " + ($prm | ForEach-Object { "$($_.Bas)-$($_.Bit)" } | Join-String -Separator " / ")
    
    $lblFooter = New-Object System.Windows.Forms.Label
    $lblFooter.Text = $txtIzin; $lblFooter.ForeColor = [System.Drawing.Color]::Gray
    $lblFooter.TextAlign = "MiddleCenter"; $lblFooter.Size = "$($scrW), 40"; $lblFooter.Top = $scrH - 80; $lblFooter.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $form.Controls.AddRange(@($lblTime, $btnM, $btnY, $txt, $btnE, $lblFooter))
    $form.ShowDialog()
}

# --- ZAMAN PANELI ---
function Show-TimerPanel {
    $c = Get-Config
    $script:kalanSn = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "200,90"; $p.StartPosition = "Manual"; $p.Location = "25, 25"; $p.FormBorderStyle = "None"
    $p.TopMost = $true; $p.BackColor = [System.Drawing.Color]::FromArgb(26, 44, 38); $p.Opacity = 0.9

    $drag = { [Win32]::ReleaseCapture(); [Win32]::SendMessage($p.Handle, 0xA1, 0x2, 0) }
    $p.Add_MouseDown($drag)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $lbl.Dock = "Fill"; $lbl.TextAlign = "MiddleCenter"; $lbl.Add_MouseDown($drag)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "MOLA VER"; $btn.Dock = "Bottom"; $btn.Height = 28; $btn.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79)
    $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderSize = 0; $btn.ForeColor = "White"

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $btn.Add_Click({ 
        $timer.Stop(); $nowCfg = Get-Config
        if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $script:kalanSn } else { $nowCfg.YagizKalanSaniye = $script:kalanSn }
        $nowCfg.SistemKilitli = $true; Save-Config $nowCfg; $p.Close()
    })

    $timer.Add_Tick({
        if (-not (Check-TimePermit)) { 
            $cfg = Get-Config; $cfg.SistemKilitli = $true; Save-Config $cfg; $p.Close() 
        }
        $script:kalanSn--
        if ($script:kalanSn -le 0) {
            $cfg = Get-Config
            if($cfg.AktifCocuk -match "Mirza") { $cfg.MirzaKalanSaniye = 3600; $cfg.AktifCocuk = "Yağız" } 
            else { $cfg.YagizKalanSaniye = 3600; $cfg.AktifCocuk = "Mirza" }
            $cfg.SistemKilitli = $true; Save-Config $cfg; $p.Close()
        }
        $ts = [TimeSpan]::FromSeconds($script:kalanSn)
        $lbl.Text = "$($c.AktifCocuk.ToUpper())`n$($ts.Minutes) dk $($ts.Seconds) sn"
    })
    
    $p.Controls.AddRange(@($lbl, $btn)); $timer.Start(); $p.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    try {
        $c = Get-Config
        if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    } catch { Write-Log "KRITIK" $_.Exception.Message }
    Start-Sleep -Seconds 1
}