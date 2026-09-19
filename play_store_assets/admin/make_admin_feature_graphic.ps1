Add-Type -AssemblyName System.Drawing

$width = 1024
$height = 500
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Background Gradient (Deep Indigo / Slate)
$rect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
$cTop = [System.Drawing.ColorTranslator]::FromHtml("#0F172A")
$cBottom = [System.Drawing.ColorTranslator]::FromHtml("#1E1B4B")
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cTop, $cBottom, 40.0)
$g.FillRectangle($bgBrush, $rect)

# Ambient glows
$glowColor = [System.Drawing.Color]::FromArgb(45, 99, 102, 241)
$glowBrush = New-Object System.Drawing.SolidBrush($glowColor)
$g.FillEllipse($glowBrush, 650, -80, 500, 500)

# Hero image on right
$heroPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\flutter_app\assets\mascot\admin_dashboard_hero.png"
if (Test-Path $heroPath) {
    $hero = [System.Drawing.Image]::FromFile($heroPath)
    $hH = 440
    $hW = [int]($hero.Width * ($hH / $hero.Height))
    $hX = $width - $hW - 30
    $hY = [int](($height - $hH) / 2) + 15
    $g.DrawImage($hero, $hX, $hY, $hW, $hH)
    $hero.Dispose()
}

# Admin Icon on left
$iconPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\admin\admin_app_icon_512x512.png"
if (Test-Path $iconPath) {
    $icon = [System.Drawing.Image]::FromFile($iconPath)
    $g.DrawImage($icon, 60, 65, 85, 85)
    $icon.Dispose()
}

# Typography
$fontTitle = New-Object System.Drawing.Font("Segoe UI", [float]32, [System.Drawing.FontStyle]::Bold)
$fontSubtitle = New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)
$descFont = New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Regular)
$fontBadge = New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Bold)

$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$indigo = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#A5B4FC"))
$muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

$g.DrawString("Social Studying AI - Admin", $fontTitle, $white, [float]165, [float]75)
$g.DrawString("Educator & Workspace Management Portal", $fontSubtitle, $indigo, [float]60, [float]180)
$g.DrawString("Upload curricula, manage learning spaces, and track student cohort progress.", $descFont, $muted, [float]60, [float]220)

# Feature Badges
$badges = @("Curriculum Management", "Document Ingestion", "Screen Time Policies", "Cohort Analytics")
$bX = 60
$bY = 295
foreach ($b in $badges) {
    $size = $g.MeasureString($b, $fontBadge)
    $bw = [int]$size.Width + 24
    $bh = 36
    $bRect = New-Object System.Drawing.Rectangle($bX, $bY, $bw, $bh)
    $bBgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 255, 255, 255))
    $bPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#818CF8"), 1.5)
    
    $g.FillRectangle($bBgBrush, $bRect)
    $g.DrawRectangle($bPen, $bRect)
    $g.DrawString($b, $fontBadge, $white, [float]($bX + 12), [float]($bY + 8))
    
    $bX += $bw + 16
}

$tagFont = New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Regular)
$tagBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#64748B"))
$g.DrawString("For Teachers, Tutors, School Admins & Academic Leaders", $tagFont, $tagBrush, [float]60, [float]380)

$destPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\admin\admin_feature_graphic_1024x500.png"
$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
Write-Host "Created $destPath"
