Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "C:\CocukTakip\config.json"

# --- SÜRÜKLEME İÇİN GEREKLİ SİSTEM KODU ---
$code = @"
using System;
using System.Runtime.InteropServices;
public class DragHelper {
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@
Add-Type -TypeDefinition $code

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

# --- KİLİT EKRANI ---
function Show-LockScreen {
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = "Maximized"; $form.FormBorderStyle = "None"; $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 45)
    $scrW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $scrH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

    $cfg = Get-Config
    $script:seciliCocuk = if ($cfg.AktifCocuk) { $cfg.AktifCocuk } else { "Mirza" }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "KULLANICI SECIN VE SIFRE GIRIN"; $lbl.ForeColor = "White"
    $lbl.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
    $lbl.TextAlign = "MiddleCenter"; $lbl.Size = "$($scrW), 80"; $lbl.Top = ($scrH / 2) - 200
    
    $btnMirza = New-Object System.Windows.Forms.Button
    $btnMirza.Text = "MIRZA"; $btnMirza.Size = "145,50"; $btnMirza.Top = ($scrH / 2) - 100
    $btnMirza.Left = ($scrW / 2) - 150; $btnMirza.FlatStyle = "Flat"; $btnMirza.ForeColor = "White"
    
    $btnYagiz = New-Object System.Windows.Forms.Button
    $btnYagiz.Text = "YAĞIZ"; $btnYagiz.Size = "145,50"; $btnYagiz.Top = ($scrH / 2) - 100
    $btnYagiz.Left = ($scrW / 2) + 5; $btnYagiz.FlatStyle = "Flat"; $btnYagiz.ForeColor = "White"

    $updateButtons = {
        if ($script:seciliCocuk -match "Mirza") { 
            $btnMirza.BackColor = "SteelBlue"; $btnYagiz.BackColor = "DimGray" 
        } else { 
            $btnYagiz.BackColor = "SteelBlue"; $btnMirza.BackColor = "DimGray" 
        }
    }
    &$updateButtons
    $btnMirza.Add_Click({ $script:seciliCocuk = "Mirza"; &$updateButtons })
    $btnYagiz.Add_Click({ $script:seciliCocuk = "Yağız"; &$updateButtons })

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.PasswordChar = "*"; $txt.Size = "300,40"; $txt.Font = New-Object System.Drawing.Font("Arial", 18)
    $txt.Left = ($scrW / 2) - 150; $txt.Top = ($scrH / 2) + 10
    
    $btnEnter = New-Object System.Windows.Forms.Button
    $btnEnter.Text = "SISTEMI AC"; $btnEnter.Size = "300,50"; $btnEnter.BackColor = "SteelBlue"; $btnEnter.ForeColor = "White"
    $btnEnter.Left = $txt.Left; $btnEnter.Top = $txt.Bottom + 20
    
    $btnEnter.Add_Click({
        $c = Get-Config
        if ($txt.Text -eq $c.AdminSifre) {
            $c.SistemKilitli = $false; $c.AdminModu = $true; Save-Config $c
            $form.Close()
        } elseif ($txt.Text.Contains($c.AnaSifre) -and (Get-Date -Format "HH:mm") -lt $c.LastHour) {
            $c.SistemKilitli = $false; $c.AdminModu = $false; 
            $c.AktifCocuk = $script:seciliCocuk
            Save-Config $c
            $form.Close()
        } else { [System.Windows.Forms.MessageBox]::Show("Gecersiz Sifre veya Yatis Saati!") }
    })
    $form.Controls.AddRange(@($lbl, $btnMirza, $btnYagiz, $txt, $btnEnter))
    $form.ShowDialog()
}

# --- ZAMANLAYICI PANELİ ---
function Show-TimerPanel {
    $p = New-Object System.Windows.Forms.Form
    $p.Size = "220,110"; $p.StartPosition = "Manual"; $p.Location = "20, 20"
    $p.FormBorderStyle = "None"; $p.TopMost = $true; 
    $p.BackColor = "DarkSlateGray"; $p.Opacity = 0.85

    # Gelişmiş Sürükle-Bırak (Heryerden tutulabilir)
    $dragHandler = {
        [DragHelper]::ReleaseCapture()
        [DragHelper]::SendMessage($p.Handle, 0xA1, 0x2, 0)
    }
    $p.Add_MouseDown($dragHandler)

    $info = New-Object System.Windows.Forms.Label
    $info.ForeColor = "White"; $info.Dock = "Fill"; $info.TextAlign = "MiddleCenter"
    $info.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $info.Add_MouseDown($dragHandler) # Yazıya tıklayınca da sürüklensin
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "KILITLE"; $btn.Dock = "Bottom"; $btn.Height = 35; 
    $btn.BackColor = "Orange"; $btn.ForeColor = "Black"; $btn.FlatStyle = "Flat"
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $btn.Add_Click({ $timer.Stop(); $timer.Dispose(); $c = Get-Config; $c.SistemKilitli = $true; $c.AdminModu = $false; Save-Config $c; $p.Close() })

    $timer.Add_Tick({
        $c = Get-Config
        if (!$c) { return }
        if ($c.AdminModu) { $info.Text = "ADMIN MODU`nSURE ISLEMIYOR"; $info.ForeColor = "Lime"; return }

        $k = if($c.AktifCocuk -match "Mirza") {"MirzaKalanSaniye"} else {"YagizKalanSaniye"}
        $c.$k -= 1
        
        if ($c.$k -le 0 -or (Get-Date -Format "HH:mm") -ge $c.LastHour) {
            if ($c.$k -le 0) { 
                $c.$k = 3600; 
                $c.AktifCocuk = if($c.AktifCocuk -match "Mirza") {"Yağız"} else {"Mirza"} 
            }
            $timer.Stop(); $timer.Dispose(); $c.SistemKilitli = $true; Save-Config $c; $p.Close()
        }
        Save-Config $c
        $ts = [TimeSpan]::FromSeconds($c.$k)
        $info.Text = $c.AktifCocuk.ToUpper() + "`n" + $ts.Minutes + " dk " + $ts.Seconds + " sn"
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