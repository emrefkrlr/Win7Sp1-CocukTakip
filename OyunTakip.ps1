Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

function Write-Log ($status, $message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$time] [$status] >> $message" | Out-File $logPath -Append -Encoding "UTF8"
}

function Get-Config { 
    if (Test-Path $configPath) { return Get-Content $configPath -Raw | ConvertFrom-Json }
    return $null
}

function Check-TimePermit {
    try {
        $cfg = Get-Config
        $now = (Get-Date).TimeOfDay
        $day = (Get-Date).DayOfWeek
        $isWeekend = ($day -eq "Saturday" -or $day -eq "Sunday")
        $permits = if ($isWeekend) { $cfg.Izinler.HaftaSonu } else { $cfg.Izinler.HaftaIci }
        
        foreach ($p in $permits) {
            if ($now -ge [TimeSpan]::Parse($p.Bas) -and $now -lt [TimeSpan]::Parse($p.Bit)) { return $true }
        }
    } catch { Write-Log "HATA" "Zaman Pars Hatasi: $($_.Exception.Message)" }
    return $false
}

function Show-LockScreen {
    Write-Log "DEBUG" "Kilit Ekrani Ciziliyor..."
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "CocukTakip Guard"; $form.TopMost = $true
    $form.FormBorderStyle = "None"; $form.WindowState = "Maximized"
    $form.BackColor = [System.Drawing.Color]::FromArgb(26, 44, 38)

    # Saat (Görseldeki Stil)
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text = Get-Date -Format "HH:mm"
    $lblTime.Font = New-Object System.Drawing.Font("Segoe UI Light", 80)
    $lblTime.ForeColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $lblTime.TextAlign = "MiddleCenter"; $lblTime.Dock = "Top"; $lblTime.Height = 250

    # Şifre Kutusu
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Font = New-Object System.Drawing.Font("Segoe UI", 20)
    $txt.Width = 300; $txt.Height = 50; $txt.Left = ([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width / 2) - 150
    $txt.Top = 400; $txt.TextAlign = "Center"

    # Giriş Butonu
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Sistemi Aç"; $btn.Width = 300; $btn.Height = 50
    $btn.Left = $txt.Left; $btn.Top = 460; $btn.BackColor = [System.Drawing.Color]::FromArgb(168, 229, 193)
    $btn.FlatStyle = "Flat"

    $btn.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre -or $txt.Text.ToLower() -eq $c.AnaSifre.ToLower()) {
            if (Check-TimePermit -or $txt.Text -eq $c.AdminSifre) {
                $c.SistemKilitli = $false; $c.AdminModu = ($txt.Text -eq $c.AdminSifre)
                $c | ConvertTo-Json | Out-File $configPath -Force
                $form.Close()
            } else { [System.Windows.Forms.MessageBox]::Show("Şu an izin saati değil!") }
        } else { $txt.Text = "Hatalı!"; Start-Sleep -s 1; $txt.Text = "" }
    })

    $form.Controls.AddRange(@($lblTime, $txt, $btn))
    $form.ShowDialog()
}

# --- ANA AKIŞ ---
Write-Log "SISTEM" "Baslatildi - Donguye Giriliyor"
while($true) {
    try {
        $cfg = Get-Config
        if ($cfg.SistemKilitli) { 
            Show-LockScreen 
        } else {
            # Sayaç Paneli Buraya (Basit Tutuldu)
            [System.Windows.Forms.MessageBox]::Show("Sistem Açıldı! Mola vermek için PC'yi yeniden başlatın veya config'i kilitleyin.")
            $cfg.SistemKilitli = $true; $cfg | ConvertTo-Json | Out-File $configPath -Force
        }
    } catch { Write-Log "KRITIK" $_.Exception.Message }
    Start-Sleep -Seconds 2
}