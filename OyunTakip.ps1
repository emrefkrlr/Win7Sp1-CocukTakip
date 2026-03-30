Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

# --- LOGLAMA ---
function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

# --- WIN32 API (SÜRÜKLEME VE ODAKLAMA İÇİN) ---
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

function Get-Config { 
    if (Test-Path $configPath) {
        return Get-Content $configPath -Raw | ConvertFrom-Json 
    }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force
}

# --- ZAMAN KONTROLÜ (GELİŞTİRİLDİ) ---
function Check-TimePermit {
    $cfg = Get-Config
    $now = (Get-Date).TimeOfDay
    $day = (Get-Date).DayOfWeek
    $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
    $permits = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
    
    foreach ($p in $permits) {
        $bas = [TimeSpan]::Parse($p.Bas)
        $bit = [TimeSpan]::Parse($p.Bit)
        if ($now -ge $bas -and $now -lt $bit) { return $true }
    }
    return $false
}

# --- KİLİT EKRANI ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = "None"; $form.WindowState = "Maximized"
    $form.TopMost = $true; $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "SİSTEM KİLİTLİ"; $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 60"; $lbl.Top = ($scrH / 2) - 250

    $script:secili = "Mirza"
    $btnM = New-Object System.Windows.Forms.Button
    $btnM.Text = "MIRZA"; $btnM.Size = "150,150"; $btnM.Top = ($scrH / 2) - 100; $btnM.Left = ($scrW / 2) - 160
    $btnM.FlatStyle = "Flat"; $btnM.FlatAppearance.BorderSize = 0; $btnM.ForeColor = "White"
    
    $btnY = New-Object System.Windows.Forms.Button
    $btnY.Text = "YAĞIZ"; $btnY.Size = "150,150"; $btnY.Top = ($scrH / 2) - 100; $btnY.Left = ($scrW / 2) + 10
    $btnY.FlatStyle = "Flat"; $btnY.FlatAppearance.BorderSize = 0; $btnY.ForeColor = "White"

    $updUI = {
        if ($script:secili -eq "Mirza") { $btnM.BackColor = "SteelBlue"; $btnY.BackColor = "DimGray" }
        else { $btnY.BackColor = "SteelBlue"; $btnM.BackColor = "DimGray" }
    }
    &$updUI
    $btnM.Add_Click({ $script:secili = "Mirza"; &$updUI })
    $btnY.Add_Click({ $script:secili = "Yağız"; &$updUI })

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Size = "320,40"; $txt.Font = New-Object System.Drawing.Font("Segoe UI", 16)
    $txt.Left = ($scrW / 2) - 160; $txt.Top = $btnM.Bottom + 30; $txt.TextAlign = "Center"
    
    $btnE = New-Object System.Windows.Forms.Button
    $btnE.Text = "GİRİŞ YAP"; $btnE.Size = "320,50"; $btnE.BackColor = "DodgerBlue"; $btnE.ForeColor = "White"
    $btnE.FlatStyle = "Flat"; $btnE.Left = $txt.Left; $btnE.Top = $txt.Bottom + 20
    
    $btnE.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close()
        } elseif ($txt.Text.ToLower().Contains($c.AnaSifre.ToLower())) {
            if (Check-TimePermit) {
                $c.SistemKilitli = $false; $c.AdminModu = $false; $c.AktifCocuk = $script:secili; Save-Config $c; $form.Close()
            } else { [System.Windows.Forms.MessageBox]::Show("Şu an kullanım saati dışındasınız!", "Bilgi") }
        } else { $txt.Text = ""; $txt.Focus() }
    })

    $form.Controls.AddRange(@($lbl, $btnM, $btnY, $txt, $btnE))
    $form.ShowDialog()
}

# --- ZAMAN PANELI (ŞEFFAF VE SÜRÜKLENEBİLİR) ---
function Show-TimerPanel {
    $c = Get-Config
    $script:kalanSn = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "180,70"; $p.StartPosition = "Manual"; $p.Location = "20, 20"; $p.FormBorderStyle = "None"
    $p.TopMost = $true; $p.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45); $p.Opacity = 0.8 # Şeffaflık

    # Sürükleme Eventi
    $drag = { [Win32]::ReleaseCapture(); [Win32]::SendMessage($p.Handle, 0xA1, 0x2, 0) }
    $p.Add_MouseDown($drag)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.ForeColor = "White"; $lbl.Dock = "Fill"; $lbl.TextAlign = "MiddleCenter"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.Add_MouseDown($drag) # Yazı üzerinden de sürüklenebilir
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "MOLA VER"; $btn.Dock = "Bottom"; $btn.Height = 22; $btn.BackColor = "OrangeRed"
    $btn.FlatStyle = "Flat"; $btn.ForeColor = "White"; $btn.Font = New-Object System.Drawing.Font("Segoe UI", 7)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $btn.Add_Click({ 
        $timer.Stop(); $nowCfg = Get-Config
        if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $script:kalanSn } else { $nowCfg.YagizKalanSaniye = $script:kalanSn }
        $nowCfg.SistemKilitli = $true; Save-Config $nowCfg; $p.Close()
    })

    $timer.Add_Tick({
        $cfg = Get-Config
        if ($cfg.AdminModu) { $lbl.Text = "ADMIN MODU"; return }
        $script:kalanSn--
        if (-not (Check-TimePermit)) { $timer.Stop(); $cfg.SistemKilitli = $true; Save-Config $cfg; $p.Close() }
        if ($script:kalanSn -le 0) {
            if($cfg.AktifCocuk -match "Mirza") { $cfg.MirzaKalanSaniye = 3600; $cfg.AktifCocuk = "Yağız" } 
            else { $cfg.YagizKalanSaniye = 3600; $cfg.AktifCocuk = "Mirza" }
            $cfg.SistemKilitli = $true; Save-Config $cfg; $timer.Stop(); $p.Close()
        }
        $ts = [TimeSpan]::FromSeconds($script:kalanSn)
        $lbl.Text = "$($cfg.AktifCocuk.ToUpper())`n$($ts.Minutes) dk $($ts.Seconds) sn"
    })
    
    $p.Controls.AddRange(@($lbl, $btn))
    $timer.Start(); $p.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    $c = Get-Config
    if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    Start-Sleep -Seconds 1
}