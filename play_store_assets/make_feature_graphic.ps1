Add-Type -AssemblyName System.Drawing

$width = 1024
$height = 500
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Background Gradient
$rect = New-Object System.Drawing.Rectangle 0, 0, $width, $height
$color1 = [System.Drawing.ColorTranslator]::FromHtml("#090D16")
$color2 = [System.Drawing.ColorTranslator]::FromHtml("#1E293B")
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $color1, $color2, 35.0
$g.FillRectangle($brush, $rect)

# Add accent glows
$glowColor = [System.Drawing.Color]::FromArgb(45, 14, 165, 233)
$glowBrush = New-Object System.Drawing.SolidBrush $glowColor
$g.FillEllipse($glowBrush, 680, -80, 480, 480)

$glowColor2 = [System.Drawing.Color]::FromArgb(35, 99, 102, 241)
$glowBrush2 = New-Object System.Drawing.SolidBrush $glowColor2
$g.FillEllipse($glowBrush2, -100, 180, 450, 450)

# Load Mascot on the right
$mascotPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\flutter_app\assets\mascot\mascot_waving.png"
if (Test-Path $mascotPath) {
    $mascot = [System.Drawing.Image]::FromFile($mascotPath)
    $mH = 430
    $mW = [int]($mascot.Width * ($mH / $mascot.Height))
    $mX = $width - $mW - 40
    $mY = [int](($height - $mH) / 2) + 20
    $g.DrawImage($mascot, $mX, $mY, $mW, $mH)
    $mascot.Dispose()
}

# Load App Logo icon for left side
$iconPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\app_icon_512x512.png"
if (Test-Path $iconPath) {
    $icon = [System.Drawing.Image]::FromFile($iconPath)
    $iconSize = 85
    $g.DrawImage($icon, 60, 65, $iconSize, $iconSize)
    $icon.Dispose()
}

# Typography
$fontTitle = New-Object System.Drawing.Font("Segoe UI", [float]34, [System.Drawing.FontStyle]::Bold)
$fontSubtitle = New-Object System.Drawing.Font("Segoe UI", [float]17, [System.Drawing.FontStyle]::Bold)
$descFont = New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Regular)
$fontBadge = New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Bold)

$whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$cyanBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
$mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

# App Title & Tagline
$g.DrawString("Social Studying AI", $fontTitle, $whiteBrush, 165, 75)
$g.DrawString("AI-Powered Adaptive Learning & Study Sessions", $fontSubtitle, $cyanBrush, 60, 180)
$g.DrawString("Personalized quizzes, smart flashcards, and real-time mastery tracking.", $descFont, $mutedBrush, 60, 220)

# Feature Badges
$badges = @("Adaptive Quizzes", "Smart Flashcards", "Mastery Tracking", "Self-Study")
$bX = 60
$bY = 295
foreach ($b in $badges) {
    $size = $g.MeasureString($b, $fontBadge)
    $bw = [int]$size.Width + 24
    $bh = 36
    $bRect = New-Object System.Drawing.Rectangle $bX, $bY, $bw, $bh
    $bBgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(45, 255, 255, 255))
    $bPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 56, 189, 248)), 1.5
    
    $g.FillRectangle($bBgBrush, $bRect)
    $g.DrawRectangle($bPen, $bRect)
    $g.DrawString($b, $fontBadge, $whiteBrush, ($bX + 12), ($bY + 8))
    
    $bX += $bw + 16
}

# Bottom Guarantee/Tag
$tagFont = New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Regular)
$tagBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#64748B"))
$g.DrawString("For Students, Schools, and Lifelong Learners", $tagFont, $tagBrush, 60, 380)

$destPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\feature_graphic_1024x500.png"
$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
Write-Host "Created $destPath"
