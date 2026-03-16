Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$iconPath = "C:\CocukTakip\logo-128x128.ico"

# --- GÜVENLİ DOSYA OKUMA/YAZMA ---
function Get-Config { 
    try {
        if (Test-Path $configPath) {
            # Dosyayı başka işlem kullanırken hata almamak için paylaşımlı aç
            $fs = New-Object System.IO.FileStream($configPath, 'Open', 'Read', 'ReadWrite')
            $sr = New-Object System.IO.StreamReader($fs)
            $content = $sr.ReadToEnd()
            $sr.Close(); $fs.Close()
            if ([string]::IsNullOrWhiteSpace($content)) { return $null }
            return $content | ConvertFrom-Json 
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    try {
        $json = $obj | ConvertTo-Json
        # Dosyayı anında kilitler ve yazar, çakışmayı %100 önler
        [System.IO.File]::WriteAllText($configPath, $json)
    } catch { }
}

# --- ŞİFRE DOĞRULAMA (SENİN KURGUNA GÖRE) ---
function Verify-Pass ($inputStr) {
    $cfg = Get-Config
    if ($null -eq $cfg) { return "FAIL" }
    
    # KURAL 1: Admin şifresi ise (Sana her şey serbest)
    if ($inputStr -eq $cfg.AdminSifre) { 
        return "ADMIN" 
    }
    
    # KURAL 2: Çocuk şifresi (Sadece LastHour'dan küçükse)
    $suan = Get-Date -Format "HH:mm"
    if ($inputStr.Contains($cfg.AnaSifre)) {
        if ($suan -lt $cfg.LastHour) {
            return "USER"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Yatis saati gecti!")
            return "FAIL"
        }
    }
    return "FAIL"
}

# --- KİLİT EKRANI (HİZALAMA DÜZELTİLDİ) ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)

    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $lbl = New-Object System.Windows.Forms.Label
    $cfg = Get-Config
    $isim = if ($cfg -and $cfg.AktifCocuk) { $cfg.AktifCocuk.ToUpper() } else { "..." }
    $lbl.Text = "SISTEM KILITLI`nSIRADAKI: " + $isim
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
        if ($res -ne "FAIL") {
            $c = Get-Config
            if ($c) {
                $c.SistemKilitli = $false
                # Admin girerse saati de geçici olarak uzatıyoruz ki hemen kilitlenmesin
                if ($res -eq "ADMIN") { $c.LastHour = "23:59" }
                Save-Config $c
                $form.Close()
            }
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
    $btn.Text = "DURDUR (YEMEK)"; $btn.Dock = "Bottom"; $btn.Height = 40; $btn.BackColor = "Orange"
    $btn.Add_Click({ 
        $c = Get-Config
        if ($c) { $c.SistemKilitli = $true; Save-Config $c; $p.Close() }
    })

    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 1000
    $t.Add_Tick({
        $c = Get-Config
        if ($null -eq $c -or $null -eq $info) { return } # Hata koruması
        
        $k = if($c.AktifCocuk -eq "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        $c.$k -= 1
        
        # Sadece süre biterse veya çocuk için saat LastHour'u geçerse kilitle
        if ($c.$k -le 0 -or (Get-Date -Format "HH:mm") -ge $c.LastHour) {
            if ($c.$k -le 0) {
                $c.$k = 3600
                $c.AktifCocuk = if($c.AktifCocuk -eq "Mirza") {"Yagiz"} else {"Mirza"}
            }
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
    $c = Get-Config
    if ($null -ne $c) {
        if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    }
    Start-Sleep -Seconds 1
}