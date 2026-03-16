# 1. Kütüphaneleri en basit yöntemle yükle
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$configPath = "C:\CocukTakip\config.json"

# --- FONKSİYONLAR ---
function Get-Config { 
    if (Test-Path $configPath) {
        $content = Get-Content $configPath -Raw
        return $content | ConvertFrom-Json 
    }
}

function Save-Config ($obj) { 
    $obj | ConvertTo-Json | Set-Content $configPath 
}

# --- ANA EKRAN (EN SADE HALİ) ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "KILIT"
    $form.WindowState = "Maximized"
    $form.FormBorderStyle = "None"
    $form.TopMost = $true
    $form.BackColor = "Black"

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "SIFRE GIRINIZ"
    $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Arial", 24)
    $lbl.Dock = "Fill"
    $lbl.TextAlign = "MiddleCenter"
    
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"
    $txt.Width = 200
    $txt.Left = ($form.Width / 2) - 100
    $txt.Top = ($form.Height / 2) + 100
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "TAMAM"
    $btn.Top = $txt.Bottom + 10
    $btn.Left = $txt.Left
    $btn.ForeColor = "Black"
    $btn.BackColor = "White"

    $btn.Add_Click({
        $cfg = Get-Config
        if ($txt.Text -like "*$($cfg.AnaSifre)*" -or $txt.Text -eq $cfg.AdminSifre) {
            $cfg.SistemKilitli = $false
            Save-Config $cfg
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Hatali!")
        }
    })

    $form.Controls.Add($lbl)
    $form.Controls.Add($txt)
    $form.Controls.Add($btn)
    $form.ShowDialog()
}

# --- TEST MESAJI ---
[System.Windows.Forms.MessageBox]::Show("Kod buraya kadar ulasti, simdi donguye giriyor.")

while($true) {
    $c = Get-Config
    if ($c.SistemKilitli -eq $true) {
        Show-LockScreen
    } else {
        # Panel yerine sadece bir mesaj kutusu verelim (Test için)
        [System.Windows.Forms.MessageBox]::Show("Sure basladi! Durdurmak icin config dosyasini degistirin.")
        break # Test amacli donguyu kiriyoruz
    }
    Start-Sleep -Seconds 2
}