Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

# --- API ARAÇLARI ---
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

function Get-Config { 
    $content = Get-Content $configPath -Raw | ConvertFrom-Json
    return $content
}
function Save-Config ($obj) { $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force }

# --- ZAMAN KONTROLÜ (HATA KORUMALI) ---
function Check-TimePermit {
    try {
        $cfg = Get-Config
        $now = (Get-Date).TimeOfDay
        $day = (Get-Date).DayOfWeek
        $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
        
        $permits = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
        
        if ($null -eq $permits) { return $false }

        foreach ($p in $permits) {
            $bas = [TimeSpan]::Parse($p.Bas)
            $bit = [TimeSpan]::Parse($p.Bit)
            if ($now -ge $bas -and $now -lt $bit) { return $true }
        }
    } catch {
        Write-Log "HATA" "Zaman kontrolu sirasinda hata: $($_.Exception.Message)"
    }
    return $false
}

# --- KİLİT EKRANI (MATERIAL YOU) ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = "None"; $form.WindowState = "Maximized"
    $form.TopMost = $true; $form.BackColor = [System.Drawing.Color]::FromArgb(26, 44, 38)

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    # Saat Widget
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text = Get-Date -Format "HH:mm"; $lblTime.ForeColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $lblTime.Font = New-Object System.Drawing.Font("Segoe UI Light", 72); $lblTime.Size = "$($scrW), 120"
    $lblTime.TextAlign = "MiddleCenter"; $lblTime.Top = ($scrH / 2) - 300

    # Kullanıcılar
    $script:secili = "Mirza"
    $btnM = New-Object System.Windows.Forms.Button; $btnM.Text = "MIRZA"; $btnM.Size = "180,180"
    $btnM.Top = ($scrH / 2) - 100; $btnM.Left = ($scrW / 2) - 190; $btnM.FlatStyle = "Flat"
    $btnM.FlatAppearance.BorderSize = 0; $btnM.ForeColor = "White"; $btnM.Font = New-Object System.Drawing.Font("Segoe UI", 14, "Bold")
    
    $btnY = New-Object System.Windows.Forms.Button; $btnY.Text = "YAĞIZ"; $btnY.Size = "180,180"
    $btnY.Top = ($scrH / 2) - 100; $btnY.Left = ($scrW / 2) + 10; $btnY.FlatStyle = "Flat"
    $btnY.FlatAppearance.BorderSize = 0; $btnY.ForeColor = "White"; $btnY.Font = New-Object System.Drawing.Font("Segoe UI", 14, "Bold")

    $updUI = {
        if ($script:secili -eq "Mirza") { $btnM.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79); $btnY.BackColor = [System.Drawing.Color]::FromArgb(40, 60, 55) }
        else { $btnY.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79); $btnM.BackColor = [System.Drawing.Color]::FromArgb(40, 60, 55) }
    }
    &$updUI
    $btnM.Add_Click({ $script:secili = "Mirza"; &$updUI })
    $btnY.Add_Click({ $script:secili = "Yağız"; &$updUI })

    # Giriş Alanı
    $txt = New-Object System.Windows.Forms.TextBox; $txt.PasswordChar = "*"; $txt.Size = "300,40"
    $txt.Font = New-Object System.Drawing.Font("Segoe UI", 18); $txt.Left = ($scrW / 2) - 150; $txt.Top = $btnM.Bottom + 40
    $txt.TextAlign = "Center"; $txt.BackColor = [System.Drawing.Color]::FromArgb(168, 229, 193); $txt.BorderStyle = "None"
    
    $btnE = New-Object System.Windows.Forms.Button; $btnE.Text = "GİRİŞ"; $btnE.Size = "300,50"
    $btnE.BackColor = [System.Drawing.Color]::FromArgb(168, 229, 193); $btnE.FlatStyle = "Flat"; $btnE.FlatAppearance.BorderSize = 0
    $btnE.Left = $txt.Left; $btnE.Top = $txt.Bottom + 15; $btnE.Font = New-Object System.Drawing.Font("Segoe UI", 12, "Bold")
    
    $btnE.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close()
        } elseif ($txt.Text.ToLower().Contains($c.AnaSifre.ToLower())) {
            if (Check-TimePermit) {
                $c.SistemKilitli = $false; $c.AdminModu = $false; $c.AktifCocuk = $script:secili; Save-Config $c; $form.Close()
            } else { [System.Windows.Forms.MessageBox]::Show("Şu an kullanım saati dışındasınız!", "Bilgi") }
        } else { $txt.Text = "" }
    })

    $form.Controls.AddRange(@($lblTime, $btnM, $btnY, $txt, $btnE))
    $form.ShowDialog()
}

# --- SAYAÇ PANELİ ---
function Show-TimerPanel {
    $c = Get-Config
    $script:kalanSn = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    
    $p = New-Object System.Windows.Forms.Form; $p.Size = "180,80"; $p.StartPosition = "Manual"
    $p.Location = "30, 30"; $p.FormBorderStyle = "None"; $p.TopMost = $true; $p.BackColor = [System.Drawing.Color]::FromArgb(26, 44, 38); $p.Opacity = 0.85

    $drag = { [Win32]::ReleaseCapture(); [Win32]::SendMessage($p.Handle, 0xA1, 0x2, 0) }
    $p.Add_MouseDown($drag)

    $lbl = New-Object System.Windows.Forms.Label; $lbl.ForeColor = [System.Drawing.Color]::FromArgb(168, 229, 193); $lbl.Dock = "Fill"
    $lbl.TextAlign = "MiddleCenter"; $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, "Bold"); $lbl.Add_MouseDown($drag)
    
    $btn = New-Object System.Windows.Forms.Button; $btn.Text = "MOLA"; $btn.Dock = "Bottom"; $btn.Height = 25
    $btn.BackColor = [System.Drawing.Color]::FromArgb(61, 90, 79); $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderSize = 0; $btn.ForeColor = "White"

    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 1000
    $btn.Add_Click({ 
        $timer.Stop(); $nowCfg = Get-Config
        if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $script:kalanSn } else { $nowCfg.YagizKalanSaniye = $script:kalanSn }
        $nowCfg.SistemKilitli = $true; Save-Config $nowCfg; $p.Close()
    })

    $timer.Add_Tick({
        $script:kalanSn--
        if (-not (Check-TimePermit) -or $script:kalanSn -le 0) { 
            $nowCfg = Get-Config
            if($script:kalanSn -le 0) {
                 if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = 3600; $nowCfg.AktifCocuk = "Yağız" } 
                 else { $nowCfg.YagizKalanSaniye = 3600; $nowCfg.AktifCocuk = "Mirza" }
            } else {
                 if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $script:kalanSn } else { $nowCfg.YagizKalanSaniye = $script:kalanSn }
            }
            $nowCfg.SistemKilitli = $true; Save-Config $nowCfg; $timer.Stop(); $p.Close() 
        }
        $ts = [TimeSpan]::FromSeconds($script:kalanSn)
        $lbl.Text = "$($c.AktifCocuk.ToUpper())`n$($ts.Minutes) dk $($ts.Seconds) sn"
    })
    
    $p.Controls.AddRange(@($lbl, $btn)); $timer.Start(); $p.ShowDialog()
}

# --- ANA DÖNGÜ ---
Write-Log "SISTEM" "Baslatildi"
while($true) {
    try {
        $c = Get-Config
        if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    } catch { Start-Sleep -Seconds 2 }
}