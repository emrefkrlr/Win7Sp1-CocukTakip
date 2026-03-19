Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"
$logPath = "C:\CocukTakip\log.txt"

# --- LOGLAMA FONKSİYONU ---
function Write-Log ($message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $message" | Out-File $logPath -Append -Encoding "UTF8"
}

# --- SÜRÜKLEME DESTEĞİ ---
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
            $content = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrEmpty($content)) { return $null }
            return $content | ConvertFrom-Json 
        }
    } catch { return $null }
}

function Save-Config ($obj) { 
    try {
        $obj | ConvertTo-Json | Out-File $configPath -Encoding "UTF8" -Force
    } catch { Write-Log "HATA: Config kaydedilemedi." }
}

# --- KİLİT EKRANI ---
function Show-LockScreen {
    Write-Log "BILGI: Kilit ekrani acildi."
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)
    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $cfg = Get-Config
    $script:secili = if ($cfg.AktifCocuk) { $cfg.AktifCocuk } else { "Mirza" }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "KULLANICI SECIN VE SIFRE GIRIN"; $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 80"; $lbl.Top = ($scrH / 2) - 200
    
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
    $txt.PasswordChar = "*"; $txt.Size = "300,40"; $txt.Font = New-Object System.Drawing.Font("Arial", 18)
    $txt.Left = ($scrW / 2) - 150; $txt.Top = ($scrH / 2) + 10
    
    $btnE = New-Object System.Windows.Forms.Button
    $btnE.Text = "SISTEMI AC"; $btnE.Size = "300,50"; $btnE.BackColor = "SteelBlue"; $btnE.ForeColor = "White"
    $btnE.Left = $txt.Left; $btnE.Top = $txt.Bottom + 20
    
    $btnE.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre) {
            Write-Log "GIRIS: Admin giris yapti."
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c; $form.Close()
        } elseif ($txt.Text.Contains($c.AnaSifre) -and (Get-Date -Format "HH:mm") -lt $c.LastHour) {
            Write-Log "GIRIS: $($script:secili) oturumu basladi."
            $c.SistemKilitli = $false; $c.AdminModu = $false; $c.AktifCocuk = $script:secili; Save-Config $c; $form.Close()
        } else { Write-Log "HATA: Gecersiz giris denemesi." }
    })
    $form.Controls.AddRange(@($lbl, $btnM, $btnY, $txt, $btnE)); $form.ShowDialog()
}

function Show-TimerPanel {
    $c = Get-Config
    # --- KRİTİK: HEDEF ZAMAN HESAPLAMA ---
    $kalan = if($c.AktifCocuk -match "Mirza") { $c.MirzaKalanSaniye } else { $c.YagizKalanSaniye }
    $script:targetTime = (Get-Date).AddSeconds($kalan)
    
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,110"; $p.StartPosition = "Manual"; $p.Location = "20, 20"; $p.FormBorderStyle = "None"
    $p.TopMost = $true; $p.BackColor = "DarkSlateGray"; $p.Opacity = 0.85

    $drag = { [DragHelper]::ReleaseCapture(); [DragHelper]::SendMessage($p.Handle, 0xA1, 0x2, 0) }
    $p.Add_MouseDown($drag)

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Fill"; $info.TextAlign = "MiddleCenter"
    $info.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold); $info.Add_MouseDown($drag)
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "SISTEMI KILITLE"; $btn.Dock = "Bottom"; $btn.Height = 35; $btn.BackColor = "Orange"; $btn.FlatStyle = "Flat"
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    
    $btn.Add_Click({ 
        $timer.Stop(); $timer.Dispose()
        $nowCfg = Get-Config
        $diff = $script:targetTime - (Get-Date)
        $kalanSn = [Math]::Max(0, [int]$diff.TotalSeconds)
        
        if($nowCfg.AktifCocuk -match "Mirza") { $nowCfg.MirzaKalanSaniye = $kalanSn } else { $nowCfg.YagizKalanSaniye = $kalanSn }
        $nowCfg.SistemKilitli = $true; Save-Config $nowCfg
        Write-Log "BILGI: Mola verildi. Kalan: $kalanSn sn"
        $p.Close()
    })

    $timer.Add_Tick({
        if ($p.Visible -eq $false) { $timer.Stop(); return }
        
        $cfg = Get-Config
        if ($cfg.AdminModu) { $info.Text = "ADMIN MODU"; return }

        $diff = $script:targetTime - (Get-Date)
        $totalSeconds = [int]$diff.TotalSeconds

        if ((Get-Date -Format "HH:mm") -ge $cfg.LastHour) {
            Write-Log "BILGI: Yatis saati geldi."
            $timer.Stop(); $cfg.SistemKilitli = $true; Save-Config $cfg; $p.Close()
        }

        if ($totalSeconds -le 0) {
            Write-Log "BILGI: Sure bitti."
            if($cfg.AktifCocuk -match "Mirza") { $cfg.MirzaKalanSaniye = 3600; $cfg.AktifCocuk = "Yağız" } 
            else { $cfg.YagizKalanSaniye = 3600; $cfg.AktifCocuk = "Mirza" }
            $cfg.SistemKilitli = $true; Save-Config $cfg
            $timer.Stop(); $timer.Dispose(); $p.Close()
        }

        $ts = [TimeSpan]::FromSeconds([Math]::Max(0, $totalSeconds))
        $info.Text = $cfg.AktifCocuk.ToUpper() + "`nKalan: " + $ts.Minutes + " dk " + $ts.Seconds + " sn"
    })
    $p.Controls.AddRange(@($info, $btn)); $timer.Start(); $p.ShowDialog()
}

# --- 🚀 ACILIS AYARLARI (ZORUNLU SIFIRLAMA) ---
Write-Log "SISTEM: Bilgisayar acildi, baslangic ayarlari yukleniyor."
$baslangic = Get-Config
if ($baslangic) {
    $baslangic.SistemKilitli = $true    # Bilgisayar açıldığında mutlaka kilitli başla
    $baslangic.AdminModu = $false      # Admin modunu kapat
    $baslangic.MirzaKalanSaniye = 3600  # Süreleri 1 saate çek (İstemiyorsan bu satırı silebilirsin)
    $baslangic.YagizKalanSaniye = 3600  # Süreleri 1 saate çek (İstemiyorsan bu satırı silebilirsin)
    Save-Config $baslangic
    Write-Log "SISTEM: Kilit aktif edildi ve sureler tazelendi."
}

# --- ANA DÖNGÜ ---
while($true) {
    $c = Get-Config
    if ($c) {
        if ($c.SistemKilitli) { Show-LockScreen } else { Show-TimerPanel }
    }
    Start-Sleep -Seconds 1
}