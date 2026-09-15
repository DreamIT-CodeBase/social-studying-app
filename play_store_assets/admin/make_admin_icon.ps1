Add-Type -AssemblyName System.Drawing

$srcPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\app_icon_512x512.png"
$destPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\admin\admin_app_icon_512x512.png"

$src = [System.Drawing.Image]::FromFile($srcPath)
$dest = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($dest)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$g.DrawImage($src, 0, 0, 512, 512)

# Add sleek ADMIN banner at bottom
$bannerH = 80
$bannerY = 512 - $bannerH
$bRect = New-Object System.Drawing.Rectangle(0, $bannerY, 512, $bannerH)
$bBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 79, 70, 229)) # Indigo-600
$g.FillRectangle($bBrush, $bRect)

$fAdmin = New-Object System.Drawing.Font("Segoe UI", [float]26, [System.Drawing.FontStyle]::Bold)
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$size = $g.MeasureString("ADMIN", $fAdmin)
$textX = [float]((512 - $size.Width) / 2)
$textY = [float]($bannerY + ($bannerH - $size.Height) / 2)
$g.DrawString("ADMIN", $fAdmin, $white, $textX, $textY)

$dest.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$dest.Dispose()
$src.Dispose()
Write-Host "Created $destPath"
