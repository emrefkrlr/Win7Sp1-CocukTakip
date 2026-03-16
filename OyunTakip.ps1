Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- AYARLAR ---
$DebugMode = $true  
$configPath = "C:\CocukTakip\config.json"
$iconPath = "C:\CocukTakip\logo-128x128.ico"

# --- FONKSİYONLAR ---
function Get-Config { 
    try {
        if (Test-Path $configPath) {
            # Dosyayı paylaşım modunda güvenli oku
            $fileStream = New-Object System.IO.FileStream($configPath, 'Open', 'Read', 'ReadWrite')
            $reader = New-Object System.IO.StreamReader($fileStream)
            $content = $reader.ReadToEnd()
            $reader.Close(); $fileStream.Close()
            
            if ([string]::IsNullOrWhiteSpace($content)) { return $null }
            return $content | ConvertFrom-Json 
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    try {
        $json = $obj | ConvertTo-Json
        # Dosyaya yazarken başka bir işlem okumasın diye kilitle ve yaz
        [System.IO.File]::WriteAllText($configPath, $json)
    } catch { 
        # Yazma başarısız olursa sessizce geç, bir sonraki saniye tekrar dener
    }
}

function Set-TaskManager ($v) {
    if ($DebugMode) { return }
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $path)) { New-Item -Path $path -Force }
    Set-ItemProperty -Path $path -Name "DisableTaskMgr" -Value $v
}

function Verify-Pass ($inputStr) {
    $cfg = Get-Config
    if ($null -eq $cfg) { return "FAIL" }
    # Admin şifresini config'den al
    if ($inputStr -eq $cfg.AdminSifre) { 
        $cfg.LastHour = "23:59"
        Save-Config $cfg
        return "ADMIN" 
    }
    if ($inputStr.Contains($cfg.AnaSifre)) { return "USER" }
    return "FAIL"
}

# --- KILIT EKRANI ---
function Show-LockScreen {
    Set-TaskManager 1
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"
    $form.TopMost = $true; $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $lbl = New-Object System.Windows.Forms.Label
    $cfg = Get-Config
    # Hata koruması: cfg null ise 'BILDIRILMEDI' yaz
    $isim = if ($cfg -and $cfg.AktifCocuk) { $cfg.AktifCocuk.ToUpper() } else { "BILDIRILMEDI" }
    $lbl.Text = "SURE DOLDU! SIFRE GIRINIZ`n(SIRADAKI: " + $isim + ")"
    $lbl.ForeColor = "White"; $lbl.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 120"; $lbl.Top = ($scrH / 2) - 80
    
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Size = "300,40"; $txt.Font = New-Object System.Drawing.Font("Arial", 18)
    $txt.Left = ($scrW / 2) - 150; $txt.Top = ($scrH / 2) + 60
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "SISTEMI AC"; $btn.Size = "300,50"; $btn.BackColor = "SteelBlue"; $btn.ForeColor = "White"
    $btn.Left = ($scrW / 2) - 150; $btn.Top = $txt.Bottom + 20
    
    $btn.Add_Click({
        $res = Verify-Pass $txt.Text
        if ($res -ne "FAIL") {
            $c = Get-Config
            if ($c) {
                $c.SistemKilitli = $false; Save-Config $c
                if ($res -eq "ADMIN") { Set-TaskManager 0 }
                $form.Close()
            }
        } else { [System.Windows.Forms.MessageBox]::Show("Sifre Yanlis!"); $txt.Clear() }
    })
    $form.Controls.AddRange(@($lbl, $txt, $btn))
    $form.ShowDialog()
}

# --- ZAMANLAYICI PANELI ---
function Show-TimerPanel {
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,130"; $p.StartPosition = "Manual"; $p.Location = "20, 20"
    $p.FormBorderStyle = "None"; $p.TopMost = $true; $p.BackColor = "DarkSlateGray"

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Fill"; $info.TextAlign = "MiddleCenter"; $info.Font = New-Object System.Drawing.Font("Arial", 11)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "DURDUR (YEMEK)"; $btn.Dock = "Bottom"; $btn.Height = 40; $btn.BackColor = "Orange"
    $btn.Add_Click({ 
        $c = Get-Config
        if ($c) { $c.SistemKilitli = $true; Save-Config $c; $p.Close() }
    })

    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 1000
    $t.Add_Tick({
        $c = Get-Config
        if ($null -eq $c) { return } # Çakışma anında bu tick'i pas geç
        
        $k = if($c.AktifCocuk -eq "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        $c.$k -= 1
        
        $suan = Get-Date -Format "HH:mm"
        # Sadece Yatış Saati ile Gece 04:00 arası koruması
        if ($suan -ge $c.LastHour -and $suan -lt "04:00") {
            $c.SistemKilitli = $true; Save-Config $c; $p.Close()
        }

        if ($c.$k -le 0) {
            $c.$k = 3600
            $c.AktifCocuk = if($c.AktifCocuk -eq "Mirza") {"Yagiz"} else {"Mirza"}
            $c.SistemKilitli = $true; Save-Config $c; $p.Close()
        }
        Save-Config $c
        $ts = [TimeSpan]::FromSeconds($c.$k)
        $info.Text = $c.AktifCocuk.ToUpper() + "`nKalan: " + $ts.Minutes + " dk " + $ts.Seconds + " sn"
    })
    $p.Controls.AddRange(@($info, $btn)); $t.Start(); $p.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    try {
        $c = Get-Config
        if ($null -ne $c) {
            if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
        }
    } catch { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 1
}