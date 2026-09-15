Add-Type -AssemblyName System.Drawing

function Create-Screenshot {
    param(
        [string]$Filename,
        [string]$BadgeText,
        [string]$MainTitle,
        [string]$SubTitle,
        [scriptblock]$DrawContent
    )

    $w = 1080
    $h = 1920
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # Dark background gradient
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $cTop = [System.Drawing.ColorTranslator]::FromHtml("#0B1120")
    $cBottom = [System.Drawing.ColorTranslator]::FromHtml("#020617")
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cTop, $cBottom, 90.0)
    $g.FillRectangle($bgBrush, $rect)

    # Ambient glow
    $glowColor = [System.Drawing.Color]::FromArgb(40, 14, 165, 233)
    $glowBrush = New-Object System.Drawing.SolidBrush($glowColor)
    $g.FillEllipse($glowBrush, [int]($w/2 - 350), 300, 700, 700)

    # Header Badge
    $fontBadge = New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)
    $badgeSize = $g.MeasureString($BadgeText, $fontBadge)
    $bWidth = [int]$badgeSize.Width + 36
    $bX = [int](($w - $bWidth) / 2)
    $bY = 110
    $bRect = New-Object System.Drawing.Rectangle($bX, $bY, $bWidth, 48)
    $bFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(35, 56, 189, 248))
    $bPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#0284C7"), 2)
    $g.FillRectangle($bFill, $bRect)
    $g.DrawRectangle($bPen, $bRect)
    $cyanBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $g.DrawString($BadgeText, $fontBadge, $cyanBrush, [float]($bX + 18), [float]($bY + 12))

    # Main Title
    $fontTitle = New-Object System.Drawing.Font("Segoe UI", [float]38, [System.Drawing.FontStyle]::Bold)
    $titleSize = $g.MeasureString($MainTitle, $fontTitle)
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString($MainTitle, $fontTitle, $whiteBrush, [float](($w - $titleSize.Width) / 2), [float]180)

    # Subtitle
    $fontSub = New-Object System.Drawing.Font("Segoe UI", [float]20, [System.Drawing.FontStyle]::Regular)
    $subSize = $g.MeasureString($SubTitle, $fontSub)
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))
    $g.DrawString($SubTitle, $fontSub, $mutedBrush, [float](($w - $subSize.Width) / 2), [float]250)

    # Phone Frame
    $phoneX = 100
    $phoneY = 360
    $phoneW = 880
    $phoneH = 1500
    $phoneRect = New-Object System.Drawing.Rectangle($phoneX, $phoneY, $phoneW, $phoneH)
    $phoneBg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0F172A"))
    $phonePen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#334155"), 4)
    $g.FillRectangle($phoneBg, $phoneRect)
    $g.DrawRectangle($phonePen, $phoneRect)

    # Notch / Top Bar
    $notch = New-Object System.Drawing.Rectangle(440, ($phoneY + 15), 200, 24)
    $notchBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))
    $g.FillRectangle($notchBrush, $notch)

    # Execute custom screen content inside phone frame
    & $DrawContent $g $phoneX $phoneY $phoneW $phoneH

    $dest = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\$Filename"
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Created $dest"
}

# --- SCREENSHOT 1: WORKSPACES ---
Create-Screenshot "screenshot_1_workspaces.png" "WORKSPACES" "AI Study Companion" "Organize subjects, choose topics & track daily goals" {
    param($g, $px, $py, $pw, $ph)
    
    $fontHead = New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString("My Learning Spaces", $fontHead, $white, [float]($px + 50), [float]($py + 80))

    $mascotPath = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\flutter_app\assets\mascot\study_buddy.png"
    if (Test-Path $mascotPath) {
        $m = [System.Drawing.Image]::FromFile($mascotPath)
        $g.DrawImage($m, ($px + $pw - 180), ($py + 60), 120, 120)
        $m.Dispose()
    }

    $c1Rect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 210), ($pw - 100), 260)
    $c1Bg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))
    $c1Pen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"), 2)
    $g.FillRectangle($c1Bg, $c1Rect)
    $g.DrawRectangle($c1Pen, $c1Rect)

    $fCardT = New-Object System.Drawing.Font("Segoe UI", [float]20, [System.Drawing.FontStyle]::Bold)
    $fCardD = New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Regular)
    $cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Self-Study Workspace", $fCardT, $cyan, [float]($px + 80), [float]($py + 240))
    $g.DrawString("Personalized study mode with custom subjects, topics and format selection.", $fCardD, $muted, [float]($px + 80), [float]($py + 285))

    $pillRect = New-Object System.Drawing.Rectangle(($px + 80), ($py + 390), 220, 42)
    $pillBg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0284C7"))
    $pillFont = New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Bold)
    $g.FillRectangle($pillBg, $pillRect)
    $g.DrawString("START STUDYING", $pillFont, $white, [float]($px + 105), [float]($py + 400))

    $c2Rect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 510), ($pw - 100), 240)
    $g.FillRectangle($c1Bg, $c2Rect)
    $g.DrawString("Biology 101 - Cell Structure", $fCardT, $white, [float]($px + 80), [float]($py + 540))
    $g.DrawString("Teacher: Mrs. Anderson • 14 Active Documents", $fCardD, $muted, [float]($px + 80), [float]($py + 585))
    $g.DrawString("Curriculum mastery: 74% • Intermediate", $fCardD, $cyan, [float]($px + 80), [float]($py + 625))

    $c3Rect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 790), ($pw - 100), 240)
    $g.FillRectangle($c1Bg, $c3Rect)
    $g.DrawString("Chemistry - Organic Bonds", $fCardT, $white, [float]($px + 80), [float]($py + 820))
    $g.DrawString("Class Workspace • 8 Modules • 120 Flashcards", $fCardD, $muted, [float]($px + 80), [float]($py + 865))
    $g.DrawString("Curriculum mastery: 58% • Beginner", $fCardD, $cyan, [float]($px + 80), [float]($py + 905))
}

# --- SCREENSHOT 2: ADAPTIVE QUIZ ---
Create-Screenshot "screenshot_2_quiz.png" "ADAPTIVE QUIZ" "Dynamic Questions" "Difficulty automatically adjusts to your mastery" {
    param($g, $px, $py, $pw, $ph)

    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))
    $green = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#10B981"))

    $fStatus = New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)
    $g.DrawString("Question 3 of 7", $fStatus, $cyan, [float]($px + 50), [float]($py + 80))
    $g.DrawString("Mastery: 72%", $fStatus, $muted, [float]($px + $pw - 200), [float]($py + 80))

    $pbBg = New-Object System.Drawing.Rectangle(($px + 50), ($py + 120), ($pw - 100), 10)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#334155"))), $pbBg)
    $fillW = [int](($pw - 100) * 0.43)
    $pbFill = New-Object System.Drawing.Rectangle(($px + 50), ($py + 120), $fillW, 10)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))), $pbFill)

    $qRect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 170), ($pw - 100), 250)
    $qBg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))
    $g.FillRectangle($qBg, $qRect)
    $fQ = New-Object System.Drawing.Font("Segoe UI", [float]20, [System.Drawing.FontStyle]::Bold)
    $qTextRect = New-Object System.Drawing.RectangleF([float]($px + 80), [float]($py + 200), [float]($pw - 160), [float]180)
    $g.DrawString("Which organelle is primarily responsible for producing ATP in eukaryotic cells?", $fQ, $white, $qTextRect)

    $optFont = New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Regular)
    $opRectA = New-Object System.Drawing.Rectangle(($px + 50), ($py + 460), ($pw - 100), 85)
    $g.FillRectangle($qBg, $opRectA)
    $g.DrawString("A. Ribosome", $optFont, $white, [float]($px + 80), [float]($py + 485))

    $opRectB = New-Object System.Drawing.Rectangle(($px + 50), ($py + 570), ($pw - 100), 85)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#064E3B"))), $opRectB)
    $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#10B981"), 2)), $opRectB)
    $g.DrawString("B. Mitochondria  ?", (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $green, [float]($px + 80), [float]($py + 595))

    $opRectC = New-Object System.Drawing.Rectangle(($px + 50), ($py + 680), ($pw - 100), 85)
    $g.FillRectangle($qBg, $opRectC)
    $g.DrawString("C. Endoplasmic Reticulum", $optFont, $white, [float]($px + 80), [float]($py + 705))

    $opRectD = New-Object System.Drawing.Rectangle(($px + 50), ($py + 790), ($pw - 100), 85)
    $g.FillRectangle($qBg, $opRectD)
    $g.DrawString("D. Golgi Apparatus", $optFont, $white, [float]($px + 80), [float]($py + 815))

    $expRect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 910), ($pw - 100), 220)
    $expBg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))
    $expPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#10B981"), 1.5)
    $g.FillRectangle($expBg, $expRect)
    $g.DrawRectangle($expPen, $expRect)

    $g.DrawString("Correct! Explanation:", (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $green, [float]($px + 80), [float]($py + 935))
    $expTextRect = New-Object System.Drawing.RectangleF([float]($px + 80), [float]($py + 975), [float]($pw - 160), [float]130)
    $g.DrawString("Mitochondria generate most of the chemical energy needed to power the biochemical reactions of eukaryotic cells via oxidative phosphorylation.", (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)), $muted, $expTextRect)
}

# --- SCREENSHOT 3: FLASHCARDS ---
Create-Screenshot "screenshot_3_flashcards.png" "SMART FLASHCARDS" "Active Recall" "Reinforce long-term memory with spaced repetition" {
    param($g, $px, $py, $pw, $ph)

    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Card 4 of 12 • Chemistry", (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $cyan, [float]($px + 50), [float]($py + 80))

    $cardRect = New-Object System.Drawing.Rectangle(($px + 50), ($py + 160), ($pw - 100), 620)
    $cardBg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))
    $cardPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#6366F1"), 3)
    $g.FillRectangle($cardBg, $cardRect)
    $g.DrawRectangle($cardPen, $cardRect)

    $tagRect = New-Object System.Drawing.Rectangle(($px + 90), ($py + 200), 160, 36)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#4F46E5"))), $tagRect)
    $g.DrawString("TERM / CONCEPT", (New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 105), [float]($py + 210))

    $fCardFront = New-Object System.Drawing.Font("Segoe UI", [float]30, [System.Drawing.FontStyle]::Bold)
    $g.DrawString("Covalent Bond", $fCardFront, $white, [float]($px + 90), [float]($py + 280))

    $fCardDef = New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Regular)
    $defRect = New-Object System.Drawing.RectangleF([float]($px + 90), [float]($py + 360), [float]($pw - 180), [float]200)
    $g.DrawString("A chemical bond that involves the sharing of electrons to form electron pairs between atoms.", $fCardDef, $muted, $defRect)

    $flipX = [int]($px + ($pw - 300) / 2)
    $flipRect = New-Object System.Drawing.Rectangle($flipX, ($py + 680), 300, 60)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0284C7"))), $flipRect)
    $g.DrawString("Tap to Flip Card ?", (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $white, [float]($flipX + 50), [float]($py + 695))

    $bY = $py + 840
    $bW = [int](($pw - 140) / 3)
    
    $r1 = New-Object System.Drawing.Rectangle(($px + 50), $bY, $bW, 80)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#064E3B"))), $r1)
    $g.DrawString("Easy", (New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#10B981"))), [float]($px + 85), [float]($bY + 25))

    $r2 = New-Object System.Drawing.Rectangle(($px + 50 + $bW + 20), $bY, $bW, 80)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E3A8A"))), $r2)
    $g.DrawString("Good", (New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)), $cyan, [float]($px + 50 + $bW + 55), [float]($bY + 25))

    $r3 = New-Object System.Drawing.Rectangle(($px + 50 + ($bW * 2) + 40), $bY, $bW, 80)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#7F1D1D"))), $r3)
    $g.DrawString("Hard", (New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#F87171"))), [float]($px + 50 + ($bW * 2) + 75), [float]($bY + 25))
}

# --- SCREENSHOT 4: ANALYTICS ---
Create-Screenshot "screenshot_4_analytics.png" "PROGRESS TRACKING" "Mastery & Analytics" "Clear insights into your growth and subject proficiency" {
    param($g, $px, $py, $pw, $ph)

    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $cyan = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#38BDF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Performance Overview", (New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]($py + 80))

    $statW = [int](($pw - 130) / 2)
    
    $s1 = New-Object System.Drawing.Rectangle(($px + 50), ($py + 150), $statW, 160)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $s1)
    $g.DrawString("Overall Mastery", (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)), $muted, [float]($px + 75), [float]($py + 175))
    $g.DrawString("84%", (New-Object System.Drawing.Font("Segoe UI", [float]36, [System.Drawing.FontStyle]::Bold)), $cyan, [float]($px + 75), [float]($py + 215))

    $s2 = New-Object System.Drawing.Rectangle(($px + 50 + $statW + 30), ($py + 150), $statW, 160)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $s2)
    $g.DrawString("Day Streak", (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)), $muted, [float]($px + 50 + $statW + 55), [float]($py + 175))
    $g.DrawString("12 Days ??", (New-Object System.Drawing.Font("Segoe UI", [float]32, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#F59E0B"))), [float]($px + 50 + $statW + 55), [float]($py + 220))

    $sY = $py + 360
    $g.DrawString("Subject Proficiency", (New-Object System.Drawing.Font("Segoe UI", [float]20, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]$sY)

    $subjects = @(
        @{ Name = "Biology - Cellular Respiration"; Score = 92; Color = "#10B981" },
        @{ Name = "Chemistry - Stoichiometry"; Score = 78; Color = "#38BDF8" },
        @{ Name = "Physics - Mechanics"; Score = 64; Color = "#F59E0B" }
    )

    $yOff = $sY + 60
    foreach ($s in $subjects) {
        $cRect = New-Object System.Drawing.Rectangle(($px + 50), $yOff, ($pw - 100), 120)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $cRect)
        
        $g.DrawString($s.Name, (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 75), [float]($yOff + 25))
        $g.DrawString("$($s.Score)%", (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($s.Color))), [float]($px + $pw - 150), [float]($yOff + 25))
        
        $bRect = New-Object System.Drawing.Rectangle(($px + 75), ($yOff + 75), ($pw - 150), 10)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#334155"))), $bRect)
        $barW = [int](($pw - 150) * ($s.Score / 100))
        $bFill = New-Object System.Drawing.Rectangle(($px + 75), ($yOff + 75), $barW, 10)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($s.Color))), $bFill)
        
        $yOff += 150
    }
}
