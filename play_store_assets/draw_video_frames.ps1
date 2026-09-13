Add-Type -AssemblyName System.Drawing

$outputDir = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\video_frames"
if (!(Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir }

$w = 1080
$h = 1920

function Draw-BaseScreen {
    param($g, $title)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0F172A"))
    $g.FillRectangle($bgBrush, $rect)

    # Top notification bar
    $topBar = New-Object System.Drawing.Rectangle(0, 0, $w, 80)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#020617"))), $topBar)
    $fTime = New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString("10:00", $fTime, $white, [float]60, [float]25)
    $g.DrawString("5G  100%", $fTime, $white, [float]($w - 180), [float]25)

    # App Header
    $headerRect = New-Object System.Drawing.Rectangle(0, 80, $w, 140)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $headerRect)
    $fTitle = New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)
    $cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $g.DrawString($title, $fTitle, $cyan, [float]60, [float]125)
}

# --- STAGE 1: APP PROFILE & TRIGGER (5 seconds = 5 frames for loop) ---
$bmp1 = New-Object System.Drawing.Bitmap $w, $h
$g1 = [System.Drawing.Graphics]::FromImage($bmp1)
$g1.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
Draw-BaseScreen $g1 "Social Studying AI - Settings"

# Menu item
$mRect = New-Object System.Drawing.Rectangle(60, 280, ($w - 120), 120)
$g1.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $mRect)
$g1.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"), 2)), $mRect)

$fM1 = New-Object System.Drawing.Font("Segoe UI", [float]20, [System.Drawing.FontStyle]::Bold)
$fM2 = New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Regular)
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

$g1.DrawString("Screen Time & Focus Protection", $fM1, $white, [float]100, [float]305)
$g1.DrawString("Tap to configure study focus & view permission disclosure", $fM2, $muted, [float]100, [float]345)

# Touch Pointer
$fTap = New-Object System.Drawing.Font("Segoe UI", [float]26, [System.Drawing.FontStyle]::Bold)
$g1.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 56, 189, 248))), 600, 320, 70, 70)
$bmp1.Save("$outputDir\stage1.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g1.Dispose(); $bmp1.Dispose()

# --- STAGE 2: PROMINENT DISCLOSURE DIALOG (10 seconds) ---
$bmp2 = New-Object System.Drawing.Bitmap $w, $h
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
Draw-BaseScreen $g2 "Social Studying AI"

# Dim background
$g2.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 0, 0, 0))), 0, 0, $w, $h)

# Dialog Card
$dRect = New-Object System.Drawing.Rectangle(70, 420, ($w - 140), 1080)
$g2.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $dRect)
$g2.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"), 3)), $dRect)

# Dialog Icon & Title
$fDTitle = New-Object System.Drawing.Font("Segoe UI", [float]26, [System.Drawing.FontStyle]::Bold)
$g2.DrawString("??? Accessibility Permission", $fDTitle, $white, [float]110, [float]470)

# Prominent Disclosure Header
$fDSub = New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)
$cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
$g2.DrawString("Prominent In-App Disclosure", $fDSub, $cyan, [float]110, [float]540)

# Disclosure Text Body
$fBody = New-Object System.Drawing.Font("Segoe UI", [float]17, [System.Drawing.FontStyle]::Regular)
$bodyText = @"
Social Studying AI uses the Android AccessibilityServices API strictly to support students during study sessions.

WHY IT IS USED:
• To detect when a student is studying and monitor focused study session duration.
• To temporarily block distracting social applications when study minutes or daily limits expire.

YOUR PRIVACY & DATA GUARANTEE:
• Does NOT read screen text, passwords, or personal messages.
• Does NOT collect, store, or transmit ANY personal or sensitive user data.
• Operates purely locally on your device with no remote transmission.

You can turn off this permission at any time in Android Settings.
"@
$rectBody = New-Object System.Drawing.RectangleF([float]110, [float]590, [float]($w - 220), [float]680)
$g2.DrawString($bodyText, $fBody, $white, $rectBody)

# Action Buttons
$btnCancel = New-Object System.Drawing.Rectangle(110, 1370, 360, 80)
$g2.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#334155"))), $btnCancel)
$fBtn = New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)
$g2.DrawString("Not Now", $fBtn, $white, [float]230, [float]1395)

$btnAccept = New-Object System.Drawing.Rectangle(510, 1370, 430, 80)
$g2.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0284C7"))), $btnAccept)
$g2.DrawString("Agree & Enable ->", $fBtn, $white, [float]610, [float]1395)

# Touch Pointer on Agree
$g2.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 56, 189, 248))), 740, 1380, 70, 70)
$bmp2.Save("$outputDir\stage2.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose(); $bmp2.Dispose()

# --- STAGE 3: ANDROID SYSTEM SETTINGS (10 seconds) ---
$bmp3 = New-Object System.Drawing.Bitmap $w, $h
$g3 = [System.Drawing.Graphics]::FromImage($bmp3)
$g3.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
Draw-BaseScreen $g3 "Android Settings > Accessibility"

$fSetTitle = New-Object System.Drawing.Font("Segoe UI", [float]22, [System.Drawing.FontStyle]::Bold)
$fSetSub = New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Regular)

# Setting Tile
$sRect = New-Object System.Drawing.Rectangle(60, 280, ($w - 120), 160)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $sRect)

$g3.DrawString("Social Studying AI", $fSetTitle, $white, [float]100, [float]315)
$g3.DrawString("Use service to manage focused study sessions", $fSetSub, $muted, [float]100, [float]365)

# Toggle Switch (ON)
$toggleRect = New-Object System.Drawing.Rectangle(($w - 220), 330, 120, 60)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#10B981"))), $toggleRect)
$g3.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), ($w - 165), 332, 56, 56)

# System Confirmation Modal
$cModal = New-Object System.Drawing.Rectangle(100, 700, ($w - 200), 550)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0F172A"))), $cModal)
$g3.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#475569"), 2)), $cModal)

$g3.DrawString("Allow Social Studying AI?", $fSetTitle, $white, [float]140, [float]740)
$sysText = "Social Studying AI needs access to monitor active applications to enforce study session time limits."
$g3.DrawString($sysText, $fSetSub, $muted, (New-Object System.Drawing.RectangleF([float]140, [float]810, [float]($w - 280), [float]200)))

$allowBtn = New-Object System.Drawing.Rectangle(($w - 360), 1130, 220, 70)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0284C7"))), $allowBtn)
$g3.DrawString("Allow", $fBtn, $white, [float]($w - 290), [float]1150)

# Touch Pointer on Allow
$g3.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 56, 189, 248))), ($w - 270), 1135, 60, 60)
$bmp3.Save("$outputDir\stage3.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g3.Dispose(); $bmp3.Dispose()

# --- STAGE 4: RETURN TO APP - VERIFIED (5 seconds) ---
$bmp4 = New-Object System.Drawing.Bitmap $w, $h
$g4 = [System.Drawing.Graphics]::FromImage($bmp4)
$g4.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
Draw-BaseScreen $g4 "Social Studying AI - Protected"

$vRect = New-Object System.Drawing.Rectangle(70, 450, ($w - 140), 400)
$g4.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#064E3B"))), $vRect)
$g4.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#10B981"), 3)), $vRect)

$fVTitle = New-Object System.Drawing.Font("Segoe UI", [float]28, [System.Drawing.FontStyle]::Bold)
$green = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#34D399"))
$g4.DrawString("? Accessibility Service Active", $fVTitle, $green, [float]120, [float]510)

$vText = @"
Study session protection is now active.
• Focused study mode enabled
• No personal data collected or stored
• Student screen time management active
"@
$g4.DrawString($vText, $fBody, $white, (New-Object System.Drawing.RectangleF([float]120, [float]580, [float]($w - 240), [float]200)))

$bmp4.Save("$outputDir\stage4.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g4.Dispose(); $bmp4.Dispose()

Write-Host "All 4 stages drawn successfully!"
