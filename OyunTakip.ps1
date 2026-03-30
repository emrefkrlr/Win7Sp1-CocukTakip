Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

# --- LOGLAMA ---
function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

# --- YARDIMCI SINIFLAR ---
$code = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"Win32").Type) { Add-Type -TypeDefinition $code }

# --- FONKSIYONLAR ---
function Get-Config { 
    if (Test-Path $configPath) {
        return Get-Content $configPath -Raw | ConvertFrom-Json 
    }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force
}

function Check-TimePermit {
    $cfg = Get-Config
    $now = Get-Date -Format "HH:mm"
    $day = (Get-Date).DayOfWeek
    $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
    $permits = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
    
    foreach ($p in $permits) {
        if ($now -ge $p.Bas -and $now -lt $p.Bit) { return $true }
    }
    return $false
}

# --- KİLİT EKRANI (V2 macOS Style) ---
function Show-LockScreen {
    $cfg = Get-Config
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Sistem Kilitli"; $form.FormBorderStyle = "None"
    $form.WindowState = "Maximized"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Dark Mode

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    # Başlık
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "LÜTFEN OTURUM AÇIN"; $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 60"; $lbl.Top = ($scrH / 2) - 250

    # İzin Saatleri Bilgisi (Geliştirme 3)
    $dayInfo = New-Object System.Windows.Forms.Label
    $day = (Get-Date).DayOfWeek
    $txtIzin = if ($day -eq "Saturday" -or $day -eq "Sunday") { "Hafta Sonu İzni: 08:30 - 22:45" } else { "Hafta İçi İzni: 08:30-17:00 / 18:30-21:30" }
    $dayInfo.Text = $txtIzin; $dayInfo.ForeColor = "Gray"; $dayInfo.TextAlign = "MiddleCenter"
    $dayInfo.Size = "$($scrW), 30"; $dayInfo.Top = $lbl.Bottom + 10; $dayInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    # Çocuk Seçimi (Butonlar)
    $script:secili = "Mirza"
    $btnM = New-Object System.Windows.Forms.Button
    $btnM.Text = "MIRZA"; $btnM.Size = "150,150"; $btnM.Top = ($scrH / 2) - 100; $btnM.Left = ($scrW / 2) - 160
    $btnM.FlatStyle = "Flat"; $btnM.FlatAppearance.BorderSize = 0; $btnM.Cursor = "Hand"
    
    $btnY = New-Object System.Windows.Forms.Button
    $btnY.Text = "YAĞIZ"; $btnY.Size = "150,150"; $btnY.Top = ($scrH / 2) - 100; $btnY.Left = ($scrW / 2) + 10
    $btnY.FlatStyle = "Flat"; $btnY.FlatAppearance.BorderSize = 0; $btnY.Cursor = "Hand"

    $updUI = {
        if ($script:secili -eq "Mirza") { 
            $btnM.BackColor = "SteelBlue"; $btnY.BackColor = "DimGray" 
        } else { 
            $btnY.BackColor = "SteelBlue"; $btnM.BackColor = "DimGray" 
        }
    }
    &$updUI

    $btnM.Add_Click({ $script:secili = "Mirza"; &$updUI })
    $btnY.Add_Click({ $script:secili = "Yağız"; &$updUI })

    # Şifre Kutusu
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "●"; $txt.Size = "320,40"; $txt.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txt.Left = ($scrW / 2) - 160; $txt.Top = $btnM.Bottom + 30; $txt.TextAlign = "Center"
    
    $btnE = New-Object System.Windows.Forms.Button
    $btnE.Text = "GİRİŞ YAP"; $btnE.Size = "320,50"; $btnE.BackColor = "DodgerBlue"; $btnE.ForeColor = "White"
    $btnE.FlatStyle = "Flat"; $btnE.Left = $txt.Left; $btnE.Top = $txt.Bottom + 20
    
    $btnE.Add_Click({
        $c = Get-Config
        # Şifre Karşılaştırma: ToLower() ile Case-Insensitive (Problem 3)
        if ($txt.Text -eq $c.AdminSifre) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close()
        } elseif ($txt.Text.ToLower().Contains($c.AnaSifre.ToLower())) {
            if (Check-TimePermit) {
                $c.SistemKilitli = $false; $c.AdminModu = $false; $c.AktifCocuk = $script:secili; Save-Config $c; $form.Close()
            } else {
                [System.Windows.Forms.MessageBox]::Show("Şu an bilgisayar kullanım saati dışındasınız!", "Zaman Sınırı")
            }
        } else {
            $txt.Text = ""; $txt.PlaceholderText = "Hatalı Şifre!"
        }
    })

    $form.Controls.AddRange(@($lbl, $dayInfo, $btnM, $btnY, $txt, $btnE))
    $form.Add_Shown({ [Win32]::SetForegroundWindow($form.Handle) })
    $form.ShowDialog()
}

# --- ZAMAN PANELI (Geliştirme 4: macOS Compact Style) ---
function Show-TimerPanel {
    $c = Get-Config
    $script:kalanSn = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "200,80"; $p.StartPosition = "Manual"; $p.Location = "20, 20"; $p.FormBorderStyle = "None"
    $p.TopMost = $true; $p.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45); $p.Opacity = 0.9

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.ForeColor = "White"; $lbl.Dock = "Fill"; $lbl.TextAlign = "MiddleCenter"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "MOLA (KİLİTLE)"; $btn.Dock = "Bottom"; $btn.Height = 25; $btn.BackColor = "#E67E22"; $btn.FlatStyle = "Flat"
    $btn.ForeColor = "White"; $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    
    $btn.Add_Click({ 
        $timer.Stop(); 
        $nowCfg = Get-Config
        if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $script:kalanSn } else { $nowCfg.YagizKalanSaniye = $script:kalanSn }
        $nowCfg.SistemKilitli = $true; Save-Config $nowCfg; $p.Close()
    })

    $timer.Add_Tick({
        $cfg = Get-Config
        if ($cfg.AdminModu) { $lbl.Text = "ADMIN MODU"; return }
        
        $script:kalanSn--

        if (-not (Check-TimePermit)) {
            Write-Log "ENGEL" "İzin saati bitti."
            $timer.Stop(); $cfg.SistemKilitli = $true; Save-Config $cfg; $p.Close()
        }

        if ($script:kalanSn -le 0) {
            Write-Log "BITIS" "Süre doldu."
            if($cfg.AktifCocuk -match "Mirza") { $cfg.MirzaKalanSaniye = 3600; $cfg.AktifCocuk = "Yağız" } 
            else { $cfg.YagizKalanSaniye = 3600; $cfg.AktifCocuk = "Mirza" }
            $cfg.SistemKilitli = $true; Save-Config $cfg
            $timer.Stop(); $p.Close()
        }

        $ts = [TimeSpan]::FromSeconds($script:kalanSn)
        $lbl.Text = "$($cfg.AktifCocuk.ToUpper())`n$($ts.Minutes) dk $($ts.Seconds) sn"
    })
    
    $p.Controls.AddRange(@($lbl, $btn))
    $timer.Start(); $p.ShowDialog()
}

# --- ANA AKIŞ ---
Write-Log "RESTART" "Bilgisayar açıldı, süreler ve kilit sıfırlandı." # Geliştirme 2
$baslangic = Get-Config
$baslangic.SistemKilitli = $true
$baslangic.AdminModu = $false
$baslangic.MirzaKalanSaniye = 3600
$baslangic.YagizKalanSaniye = 3600
Save-Config $baslangic

while($true) {
    $c = Get-Config
    if ($c.SistemKilitli) { 
        # Güvenlik: Kilitliyken explorer'ı kısıtla (Opsiyonel: stop-process -name explorer -force)
        Show-LockScreen 
    } else { 
        Show-TimerPanel 
    }
    Start-Sleep -Seconds 1
}