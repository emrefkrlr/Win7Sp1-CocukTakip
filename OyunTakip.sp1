Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"

# --- FONKSİYONLAR ---

function Get-Config { Get-Content $configPath | ConvertFrom-Json }

function Save-Config ($obj) { $obj | ConvertTo-Json | Set-Content $configPath }

# Görev Yöneticisi Kontrolü (1: Engelle, 0: Aç)
function Set-TaskManager ($v) {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $path)) { New-Item -Path $path -Force }
    Set-ItemProperty -Path $path -Name "DisableTaskMgr" -Value $v
}

# Şifre Doğrulama (Senin istediğin karmaşık mantık)
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
    $form.Text = "Sistem Kilitli"; $form.WindowState = "Maximized"
    $form.FormBorderStyle = "None"; $form.TopMost = $true; $form.BackColor = "Black"

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "LÜTFEN ŞİFRE GİRİNİZ`n(Sıradaki: $((Get-Config).AktifCocuk))"
    $lbl.ForeColor = "Cyan"; $lbl.Font = New-Object System.Drawing.Font("Arial", 28); $lbl.Dock = "Fill"; $lbl.TextAlign = "MiddleCenter"
    
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Width = 300; $txt.Left = ($form.Width/2 - 150); $txt.Top = ($form.Height/2 + 100)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "GİRİŞ"; $btn.Top = $txt.Bottom + 10; $btn.Left = $txt.Left; $btn.Width = 300; $btn.ForeColor = "White"

    $btn.Click += {
        $res = Verify-Pass $txt.Text
        if ($res -ne "FAIL") {
            $c = Get-Config; $c.SistemKilitli = $false; Save-Config $c
            if ($res -eq "ADMIN") { Set-TaskManager 0 }
            $form.Close()
        } else { [System.Windows.Forms.MessageBox]::Show("Hatalı!") }
    }
    $form.Controls.AddRange(@($lbl, $txt, $btn))
    $form.ShowDialog()
}

# --- KÜÇÜK ZAMANLAYICI PANELİ ---
# Bu panel oyun sırasında köşede durur
function Show-TimerPanel {
    $timerForm = New-Object System.Windows.Forms.Form
    $timerForm.Size = "200,120"; $timerForm.StartPosition = "Manual"
    $timerForm.Location = "20,20"; $timerForm.FormBorderStyle = "None"
    $timerForm.TopMost = $true; $timerForm.BackColor = "DarkSlateBlue"

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Top"; $info.TextAlign = "MiddleCenter"
    
    $btnPause = New-Object System.Windows.Forms.Button
    $btnPause.Text = "YEMEĞE GİDİYORUM (DURDUR)"; $btnPause.Dock = "Bottom"; $btnPause.Height = 40; $btnPause.BackColor = "Orange"

    $btnPause.Click += {
        $c = Get-Config; $c.SistemKilitli = $true; Save-Config $c
        $timerForm.Close()
    }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        $c = Get-Config
        $active = $c.AktifCocuk
        $key = if($active -eq "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        
        # Saniye düşür
        $c.$key -= 1
        
        # Gece saati kontrolü
        if ((Get-Date -Format "HH:mm") -ge $c.LastHour) {
            $c.SistemKilitli = $true; Save-Config $c; $timerForm.Close()
        }

        # Süre bitti mi?
        if ($c.$key -le 0) {
            $c.$key = 3600 # Yeni tur için 1 saat ver
            $c.AktifCocuk = if($active -eq "Mirza") {"Yagiz"} else {"Mirza"}
            $c.SistemKilitli = $true; Save-Config $c
            $timerForm.Close()
        }
        
        Save-Config $c
        $info.Text = "$active`nKalan: $([TimeSpan]::FromSeconds($c.$key).ToString('mm\:ss'))"
    })

    $timerForm.Controls.AddRange(@($info, $btnPause))
    $timer.Start()
    $timerForm.ShowDialog()
}

# --- ANA DÖNGÜ ---
while($true) {
    $c = Get-Config
    if ($c.SistemKilitli) {
        Show-LockScreen
    } else {
        Show-TimerPanel
    }
    Start-Sleep -Seconds 1
}