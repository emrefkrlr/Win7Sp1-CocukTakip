Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"
$usagePath = "C:\CocukTakip\kullanim.txt"

function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

# ================= KULLANIM LOG =================
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

# ================= SAAT KONTROL =================
function Is-AllowedTime {

    $now = Get-Date
    $day = $now.DayOfWeek

    if ($day -in @("Saturday","Sunday")) {
        $slots = $config.HaftaSonu
    } else {
        $slots = $config.HaftaIci
    }

    foreach ($slot in $slots) {
        $start = Get-Date "$($now.ToShortDateString()) $($slot.start)"
        $end   = Get-Date "$($now.ToShortDateString()) $($slot.end)"

        if ($now -ge $start -and $now -le $end) {
            return $true
        }
    }

    return $false
}

# ================= CONFIG =================
function Get-Config { 
    try {
        if (Test-Path $configPath) {
            return (Get-Content $configPath -Raw | ConvertFrom-Json)
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force
}

# ================= LOCK SCREEN =================
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
    $btnM.Left = ($scrW / 2) - 150; $btnM.FlatStyle = "Flat"; $btnM.ForeColor = "White"

    $btnY = New-Object System.Windows.Forms.Button
    $btnY.Text = "YAĞIZ"; $btnY.Size = "145,50"; $btnY.Top = ($scrH / 2) - 100
    $btnY.Left = ($scrW / 2) + 5; $btnY.FlatStyle = "Flat"; $btnY.ForeColor = "White"

    $upd = {
        if ($script:secili -match "Mirza") { $btnM.BackColor = "SteelBlue"; $btnY.BackColor = "DimGray" }
        else { $btnY.BackColor = "SteelBlue"; $btnM.BackColor = "DimGray" }
    }
    &$upd

    $btnM.Add_Click({ $script:secili = "Mirza"; &$upd })
    $btnY.Add_Click({ $script:secili = "Yağız"; &$upd })

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"
    $txt.Size = "300,40"
    $txt.Font = New-Object System.Drawing.Font("Arial", 18)
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
    $btnE.BackColor = "SteelBlue"
    $btnE.ForeColor = "White"
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

# ================= TIMER =================
function Show-TimerPanel {

    Init-UsageTracking

    $c = Get-Config
    $kalanSn = if($c.AktifCocuk -eq "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    $target = (Get-Date).AddSeconds($kalanSn)

    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,110"
    $p.TopMost = $true
    $p.BackColor = "DarkSlateGray"

    $info = New-Object System.Windows.Forms.Label
    $info.Dock = "Fill"
    $info.ForeColor = "White"
    $info.TextAlign = "MiddleCenter"

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $timer.Add_Tick({

        $cfg = Get-Config

        if (-not (Is-AllowedTime)) {
            Write-UsageLog
            $cfg.SistemKilitli = $true
            Save-Config $cfg
            $timer.Stop()
            $p.Close()
        }

        $diff = $target - (Get-Date)
        $sec = [int]$diff.TotalSeconds

        if ($sec -le 0) {
            Write-UsageLog

            if($cfg.AktifCocuk -eq "Mirza") {
                $cfg.MirzaKalanSaniye = 3600
                $cfg.AktifCocuk = "Yağız"
            } else {
                $cfg.YagizKalanSaniye = 3600
                $cfg.AktifCocuk = "Mirza"
            }

            $cfg.SistemKilitli = $true
            Save-Config $cfg
            $timer.Stop()
            $p.Close()
        }

        $ts = [TimeSpan]::FromSeconds([Math]::Max(0,$sec))
        $info.Text = "$($cfg.AktifCocuk)`n$($ts.Minutes) dk $($ts.Seconds) sn"
    })

    $p.Controls.Add($info)
    $timer.Start()
    $p.ShowDialog()
}

# ================= RESET =================
$baslangic = Get-Config
$baslangic.SistemKilitli = $true
$baslangic.AdminModu = $false
$baslangic.MirzaKalanSaniye = 3600
$baslangic.YagizKalanSaniye = 3600
Save-Config $baslangic

# ================= LOOP =================
while($true){
    $config = Get-Config
    if($config.SistemKilitli){ Show-LockScreen } else { Show-TimerPanel }
}