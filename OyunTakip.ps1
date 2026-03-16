Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"

# --- GÜVENLİ DOSYA SİSTEMİ ---
function Get-Config { 
    try {
        if (Test-Path $configPath) {
            $content = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($content)) { return $null }
            return $content | ConvertFrom-Json 
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    try {
        $json = $obj | ConvertTo-Json
        $json | Out-File $configPath -Encoding "UTF8" -Force
    } catch { }
}

# --- GİRİŞ KONTROLÜ ---
function Verify-Pass ($inputStr) {
    $cfg = Get-Config
    if (!$cfg) { return "FAIL" }
    
    # 1. Admin Girişi (Sana her şey serbest, kilit kalkar)
    if ($inputStr -eq $cfg.AdminSifre) { return "ADMIN" }
    
    # 2. Çocuk Girişi (Saat kontrolü)
    $suan = Get-Date -Format "HH:mm"
    if ($inputStr.Contains($cfg.AnaSifre)) {
        if ($suan -lt $cfg.LastHour) { return "USER" }
    }
    return "FAIL"
}

# --- KİLİT EKRANI ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)
    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $lbl = New-Object System.Windows.Forms.Label
    $cfg = Get-Config
    $isim = if ($cfg.AktifCocuk) { $cfg.AktifCocuk.ToUpper() } else { "MIRZA/YAGIZ" }
    $lbl.Text = "SURE DOLDU VEYA YATIS SAATI`nSIRADAKI: $isim"
    $lbl.ForeColor = "White"; $lbl.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 120"; $lbl.Top = ($scrH / 2) - 100
    
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Size = "300,40"; $txt.Font = New-Object System.Drawing.Font("Arial", 18)
    $txt.Left = ($scrW / 2) - 150; $txt.Top = ($scrH / 2) + 20
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "SISTEMI AC"; $btn.Size = "300,50"; $btn.BackColor = "SteelBlue"; $btn.ForeColor = "White"
    $btn.Left = $txt.Left; $btn.Top = $txt.Bottom + 20
    
    $btn.Add_Click({
        $res = Verify-Pass $txt.Text
        if ($res -eq "ADMIN") {
            $c = Get-Config; $c.SistemKilitli = $false; $c.LastHour = "23:59"; Save-Config $c
            $form.Close()
        } elseif ($res -eq "USER") {
            $c = Get-Config; $c.SistemKilitli = $false; Save-Config $c
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Gecersiz Sifre veya Yatis Saati!")
        }
    })
    $form.Controls.AddRange(@($lbl, $txt, $btn)); $form.ShowDialog()
}

# --- ZAMANLAYICI PANELİ ---
function Show-TimerPanel {
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,130"; $p.StartPosition = "Manual"; $p.Location = "20, 20"
    $p.FormBorderStyle = "None"; $p.TopMost = $true; $p.BackColor = "DarkSlateGray"

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Fill"; $info.TextAlign = "MiddleCenter"; $info.Font = New-Object System.Drawing.Font("Arial", 11)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "DURDUR"; $btn.Dock = "Bottom"; $btn.Height = 40; $btn.BackColor = "Orange"
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $btn.Add_Click({ 
        $timer.Stop(); $c = Get-Config; $c.SistemKilitli = $true; Save-Config $c; $p.Close() 
    })

    $timer.Add_Tick({
        $c = Get-Config
        if (!$c) { return }
        
        $k = if($c.AktifCocuk -eq "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        $c.$k -= 1
        
        # Süre biterse veya Saat geçerse kilitle
        if ($c.$k -le 0 -or (Get-Date -Format "HH:mm") -ge $c.LastHour) {
            if ($c.$k -le 0) {
                $c.$k = 3600
                $c.AktifCocuk = if($c.AktifCocuk -eq "Mirza") {"Yagiz"} else {"Mirza"}
            }
            $timer.Stop(); $c.SistemKilitli = $true; Save-Config $c; $p.Close()
        }
        Save-Config $c
        $ts = [TimeSpan]::FromSeconds($c.$k)
        $info.Text = $c.AktifCocuk.ToUpper() + "`nKalan: " + $ts.Minutes + " dk " + $ts.Seconds + " sn"
    })

    $p.Controls.AddRange(@($info, $btn)); $timer.Start(); $p.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    $c = Get-Config
    if ($null -ne $c) {
        if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    }
    Start-Sleep -Seconds 1
}