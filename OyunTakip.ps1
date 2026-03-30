Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"
$usagePath = "C:\CocukTakip\kullanim.txt"

# --- LOG ---
function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

# --- KULLANIM TAKİP ---
$global:baslangicSureleri = @{}

function Init-UsageTracking {
    $c = Get-Config
    if ($c) {
        $global:baslangicSureleri["Mirza"] = $c.MirzaKalanSaniye
        $global:baslangicSureleri["Yağız"] = $c.YagizKalanSaniye
    }
}

function Write-UsageLog {
    $c = Get-Config
    if (-not $c) { return }

    $today = Get-Date -Format "dd.MM.yyyy"

    foreach ($cocuk in @("Mirza","Yağız")) {
        $ilk = $global:baslangicSureleri[$cocuk]
        $son = if ($cocuk -eq "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }

        if ($ilk -ne $null -and $son -ne $null) {
            $kullanilan = $ilk - $son
            if ($kullanilan -gt 0) {
                $saat = [math]::Floor($kullanilan / 3600)
                $dk   = [math]::Floor(($kullanilan % 3600) / 60)

                $text = ""
                if ($saat -gt 0) { $text += "$saat Sa " }
                if ($dk -gt 0) { $text += "$dk dk" }

                if ($text -ne "") {
                    "$today - $cocuk - $text" | Out-File $usagePath -Append -Encoding UTF8
                    Write-Log "KULLANIM" "$today - $cocuk - $text"
                }
            }
        }
    }
}

# --- DRAG ---
$code = @"
using System;
using System.Runtime.InteropServices;
public class DragHelper {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"DragHelper").Type) { Add-Type -TypeDefinition $code }

function Get-Config { 
    try {
        if (Test-Path $configPath) {
            $content = Get-Content $configPath -Raw
            if ([string]::IsNullOrEmpty($content)) { return $null }
            return $content | ConvertFrom-Json 
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force
}

# --- SAAT KONTROL ---
function Is-AllowedTime {
    $c = Get-Config
    if ($c.AdminModu) { return $true }

    $now = Get-Date
    $day = $now.DayOfWeek

    if ($day -in @("Saturday","Sunday")) {
        $slots = $c.HaftaSonu
    } else {
        $slots = $c.HaftaIci
    }

    foreach ($slot in $slots) {
        $start = Get-Date "$($now.ToShortDateString()) $($slot.start)"
        $end   = Get-Date "$($now.ToShortDateString()) $($slot.end)"
        if ($now -ge $start -and $now -le $end) { return $true }
    }
    return $false
}

# --- KİLİT EKRANI ---
function Show-LockScreen {

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $cfg = Get-Config
    $script:secili = if ($cfg.AktifCocuk) { $cfg.AktifCocuk } else { "Mirza" }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "KULLANICI SECIN VE SIFRE GIRIN"
    $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.Size = "$($scrW), 80"
    $lbl.Top = ($scrH / 2) - 200

    $btnM = New-Object System.Windows.Forms.Button
    $btnM.Text = "MIRZA"; $btnM.Size = "145,50"; $btnM.Top = ($scrH / 2) - 100
    $btnM.Left = ($scrW / 2) - 150

    $btnY = New-Object System.Windows.Forms.Button
    $btnY.Text = "YAĞIZ"; $btnY.Size = "145,50"; $btnY.Top = ($scrH / 2) - 100
    $btnY.Left = ($scrW / 2) + 5

    $btnM.Add_Click({ $script:secili = "Mirza" })
    $btnY.Add_Click({ $script:secili = "Yağız" })

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"
    $txt.Size = "300,40"
    $txt.Left = ($scrW / 2) - 150
    $txt.Top = ($scrH / 2) + 10

    $msg = New-Object System.Windows.Forms.Label
    $msg.ForeColor = "Red"
    $msg.Size = "400,30"
    $msg.Left = $txt.Left
    $msg.Top = $txt.Bottom + 5

    $btnE = New-Object System.Windows.Forms.Button
    $btnE.Text = "SISTEMI AC"
    $btnE.Size = "300,50"
    $btnE.Left = $txt.Left
    $btnE.Top = $txt.Bottom + 40

    $btnE.Add_Click({

        $c = Get-Config
        $input = $txt.Text.ToLower()

        if ($input -eq $c.AdminSifre.ToLower()) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close(); return
        }

        if (-not (Is-AllowedTime)) {
            $msg.Text = "Bu saatlerde kullanamazsın!"
            return
        }

        $kalan = if ($script:secili -eq "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }

        if ($kalan -le 0) {
            $msg.Text = "Bugünkü süren doldu!"
            return
        }

        if ($input -eq $c.AnaSifre.ToLower()) {
            Init-UsageTracking
            $c.SistemKilitli = $false
            $c.AdminModu = $false
            $c.AktifCocuk = $script:secili
            Save-Config $c
            $form.Close()
        } else {
            $msg.Text = "Şifre hatalı!"
        }
    })

    $form.Controls.AddRange(@($lbl,$btnM,$btnY,$txt,$btnE,$msg))
    $form.ShowDialog()
}

# --- TIMER PANEL (ORİJİNAL KORUNDU) ---
function Show-TimerPanel {

    $c = Get-Config
    $now = Get-Date
    $kalanSn = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }

    $script:targetTime = $now.AddSeconds($kalanSn)

    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,110"; $p.StartPosition = "Manual"; $p.Location = "20, 20"; $p.FormBorderStyle = "None"
    $p.TopMost = $true; $p.BackColor = "DarkSlateGray"; $p.Opacity = 0.85

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Fill"; $info.TextAlign = "MiddleCenter"

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "MOLA VER (KILITLE)"; $btn.Dock = "Bottom"; $btn.Height = 35

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $btn.Add_Click({
        Write-UsageLog
        $timer.Stop()
        $cfg = Get-Config
        $cfg.SistemKilitli = $true
        Save-Config $cfg
        $p.Close()
    })

    $timer.Add_Tick({

        if (-not (Is-AllowedTime)) {
            Write-UsageLog
            $cfg = Get-Config
            $cfg.SistemKilitli = $true
            Save-Config $cfg
            $timer.Stop()
            $p.Close()
        }

        $cfg = Get-Config
        $diff = $script:targetTime - (Get-Date)
        $sec = [int]$diff.TotalSeconds

        if ($sec -le 0) {
            Write-UsageLog
            if($cfg.AktifCocuk -match "Mirza") { $cfg.MirzaKalanSaniye = 3600; $cfg.AktifCocuk = "Yağız" } 
            else { $cfg.YagizKalanSaniye = 3600; $cfg.AktifCocuk = "Mirza" }

            $cfg.SistemKilitli = $true
            Save-Config $cfg
            $timer.Stop()
            $p.Close()
        }

        $ts = [TimeSpan]::FromSeconds([Math]::Max(0, $sec))
        $info.Text = $cfg.AktifCocuk + "`n" + $ts.Minutes + " dk " + $ts.Seconds + " sn"
    })

    $p.Controls.AddRange(@($info, $btn))
    $timer.Start()
    $p.ShowDialog()
}

# --- RESET ---
$baslangic = Get-Config
$baslangic.SistemKilitli = $true
$baslangic.AdminModu = $false
$baslangic.MirzaKalanSaniye = 3600
$baslangic.YagizKalanSaniye = 3600
Save-Config $baslangic

# --- LOOP ---
while($true){
    $c = Get-Config
    if($c.SistemKilitli){ Show-LockScreen } else { Show-TimerPanel }
}