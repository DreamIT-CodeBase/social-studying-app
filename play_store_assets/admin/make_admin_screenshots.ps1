Add-Type -AssemblyName System.Drawing

function Create-AdminScreenshot {
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

    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $cTop = [System.Drawing.ColorTranslator]::FromHtml("#0F172A")
    $cBottom = [System.Drawing.ColorTranslator]::FromHtml("#1E1B4B")
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cTop, $cBottom, 90.0)
    $g.FillRectangle($bgBrush, $rect)

    # Ambient glow
    $glowColor = [System.Drawing.Color]::FromArgb(40, 99, 102, 241)
    $glowBrush = New-Object System.Drawing.SolidBrush($glowColor)
    $g.FillEllipse($glowBrush, [int]($w/2 - 350), 300, 700, 700)

    # Badge
    $fontBadge = New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)
    $badgeSize = $g.MeasureString($BadgeText, $fontBadge)
    $bWidth = [int]$badgeSize.Width + 36
    $bX = [int](($w - $bWidth) / 2)
    $bY = 110
    $bRect = New-Object System.Drawing.Rectangle($bX, $bY, $bWidth, 48)
    $bFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(35, 99, 102, 241))
    $bPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#6366F1"), 2)
    $g.FillRectangle($bFill, $bRect)
    $g.DrawRectangle($bPen, $bRect)
    $indigoBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#A5B4FC"))
    $g.DrawString($BadgeText, $fontBadge, $indigoBrush, [float]($bX + 18), [float]($bY + 12))

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

    # Notch
    $notch = New-Object System.Drawing.Rectangle(440, ($phoneY + 15), 200, 24)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $notch)

    & $DrawContent $g $phoneX $phoneY $phoneW $phoneH

    $dest = "c:\Users\tarun\Downloads\Social-studying-app\social-studying-app\play_store_assets\admin\$Filename"
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Created $dest"
}

# --- SCREENSHOT 1: DASHBOARD ---
Create-AdminScreenshot "admin_screenshot_1_dashboard.png" "WORKSPACE MANAGEMENT" "Centralized Admin Portal" "Manage academic workspaces, students & instructors" {
    param($g, $px, $py, $pw, $ph)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $indigo = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#818CF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Active Workspaces", (New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]($py + 80))

    # Metric Row (3 boxes)
    $mW = [int](($pw - 140) / 3)
    $metrics = @(
        @{ Label = "Workspaces"; Val = "8" },
        @{ Label = "Students"; Val = "142" },
        @{ Label = "Documents"; Val = "36" }
    )
    $xM = $px + 50
    foreach ($m in $metrics) {
        $r = New-Object System.Drawing.Rectangle($xM, ($py + 140), $mW, 120)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $r)
        $g.DrawString($m.Label, (New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Regular)), $muted, [float]($xM + 20), [float]($py + 160))
        $g.DrawString($m.Val, (New-Object System.Drawing.Font("Segoe UI", [float]28, [System.Drawing.FontStyle]::Bold)), $indigo, [float]($xM + 20), [float]($py + 190))
        $xM += $mW + 20
    }

    # Workspace list
    $wList = @(
        @{ Title = "AP Biology - Grade 11"; Enrolled = "28 Students"; Docs = "12 Documents"; Code = "BIO-8821" },
        @{ Title = "General Chemistry Lab"; Enrolled = "34 Students"; Docs = "9 Documents"; Code = "CHEM-4019" },
        @{ Title = "World History Honors"; Enrolled = "22 Students"; Docs = "15 Documents"; Code = "HIST-1102" }
    )
    $yW = $py + 300
    foreach ($w in $wList) {
        $c = New-Object System.Drawing.Rectangle(($px + 50), $yW, ($pw - 100), 160)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $c)
        $g.DrawString($w.Title, (New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 75), [float]($yW + 25))
        $g.DrawString("$($w.Enrolled) • $($w.Docs)", (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)), $muted, [float]($px + 75), [float]($yW + 65))
        
        # Code badge
        $b = New-Object System.Drawing.Rectangle(($px + 75), ($yW + 105), 140, 32)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#312E81"))), $b)
        $g.DrawString("Code: $($w.Code)", (New-Object System.Drawing.Font("Segoe UI", [float]11, [System.Drawing.FontStyle]::Bold)), $indigo, [float]($px + 85), [float]($yW + 112))
        
        $yW += 190
    }
}

# --- SCREENSHOT 2: DOCUMENT INGESTION ---
Create-AdminScreenshot "admin_screenshot_2_documents.png" "CURRICULUM INGESTION" "AI Document Ingestion" "Upload syllabi, textbooks & generate knowledge chunks" {
    param($g, $px, $py, $pw, $ph)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $indigo = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#818CF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))
    $green = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#10B981"))

    $g.DrawString("Document Processing", (New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]($py + 80))

    # Upload dropzone card
    $dz = New-Object System.Drawing.Rectangle(($px + 50), ($py + 140), ($pw - 100), 180)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $dz)
    $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#6366F1"), 2)), $dz)
    $g.DrawString("?? Upload New Syllabus or Textbook", (New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)), $indigo, [float]($px + 180), [float]($py + 190))
    $g.DrawString("Supports PDF, DOCX, EPUB • Instant AI Chunking", (New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Regular)), $muted, [float]($px + 230), [float]($py + 230))

    # Ingestion Status List
    $docs = @(
        @{ Name = "Cellular_Biology_Chapter_4.pdf"; Size = "4.2 MB"; Status = "Ready (48 Chunks)"; P = 100 },
        @{ Name = "Biochemistry_Principles.pdf"; Size = "12.8 MB"; Status = "Extracting Concepts…"; P = 75 },
        @{ Name = "Lab_Safety_Protocol_v2.docx"; Size = "1.1 MB"; Status = "Ready (12 Chunks)"; P = 100 }
    )
    $yD = $py + 360
    foreach ($d in $docs) {
        $c = New-Object System.Drawing.Rectangle(($px + 50), $yD, ($pw - 100), 150)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $c)
        $g.DrawString($d.Name, (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 75), [float]($yD + 25))
        $g.DrawString("$($d.Size) • $($d.Status)", (New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Regular)), $green, [float]($px + 75), [float]($yD + 60))
        
        # Progress Bar
        $pb = New-Object System.Drawing.Rectangle(($px + 75), ($yD + 105), ($pw - 150), 8)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#334155"))), $pb)
        $fill = New-Object System.Drawing.Rectangle(($px + 75), ($yD + 105), [int](($pw - 150) * ($d.P / 100)), 8)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#6366F1"))), $fill)

        $yD += 180
    }
}

# --- SCREENSHOT 3: TAXONOMY ---
Create-AdminScreenshot "admin_screenshot_3_taxonomy.png" "CURRICULUM HIERARCHY" "Taxonomy & Topics" "Inspect and customize subjects, topics & learning objectives" {
    param($g, $px, $py, $pw, $ph)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $indigo = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#818CF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Curriculum Tree", (New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]($py + 80))

    $taxNodes = @(
        @{ Title = "Module 1: Cellular Energetics"; Level = 0; Count = "24 Qs" },
        @{ Title = "+- Topic 1.1: Glycolysis & Fermentation"; Level = 1; Count = "8 Qs" },
        @{ Title = "+- Topic 1.2: Krebs Cycle (TCA)"; Level = 1; Count = "10 Qs" },
        @{ Title = "+- Topic 1.3: Oxidative Phosphorylation"; Level = 1; Count = "6 Qs" },
        @{ Title = "Module 2: Molecular Genetics"; Level = 0; Count = "32 Qs" },
        @{ Title = "+- Topic 2.1: DNA Replication & Repair"; Level = 1; Count = "14 Qs" },
        @{ Title = "+- Topic 2.2: Transcription & Translation"; Level = 1; Count = "18 Qs" }
    )

    $yT = $py + 150
    foreach ($n in $taxNodes) {
        $c = New-Object System.Drawing.Rectangle(($px + 50), $yT, ($pw - 100), 75)
        $bg = if ($n.Level -eq 0) { "#1E293B" } else { "#0F172A" }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($bg))), $c)
        if ($n.Level -eq 0) {
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#4338CA"), 1.5)), $c)
        }
        
        $fNode = if ($n.Level -eq 0) { (New-Object System.Drawing.Font("Segoe UI", [float]15, [System.Drawing.FontStyle]::Bold)) } else { (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)) }
        $colNode = if ($n.Level -eq 0) { $white } else { $muted }
        $g.DrawString($n.Title, $fNode, $colNode, [float]($px + 75), [float]($yT + 25))
        $g.DrawString($n.Count, (New-Object System.Drawing.Font("Segoe UI", [float]13, [System.Drawing.FontStyle]::Bold)), $indigo, [float]($px + $pw - 170), [float]($yT + 25))
        
        $yT += 90
    }
}

# --- SCREENSHOT 4: POLICIES ---
Create-AdminScreenshot "admin_screenshot_4_policies.png" "STUDY TIME POLICIES" "Screen Time & Focus" "Configure earn-rate rules and study incentives for students" {
    param($g, $px, $py, $pw, $ph)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $indigo = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#818CF8"))
    $muted = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#94A3B8"))

    $g.DrawString("Focus & Screen Time Rules", (New-Object System.Drawing.Font("Segoe UI", [float]24, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), [float]($py + 80))

    # Ratio rule card
    $rCard = New-Object System.Drawing.Rectangle(($px + 50), ($py + 150), ($pw - 100), 200)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $rCard)
    $g.DrawString("Study Conversion Ratio", (New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 80), [float]($py + 180))
    $g.DrawString("5 Questions Correct = 15 Minutes Earned Time", (New-Object System.Drawing.Font("Segoe UI", [float]14, [System.Drawing.FontStyle]::Regular)), $indigo, [float]($px + 80), [float]($py + 220))
    $g.DrawString("Students earn access to entertainment & social media apps by answering curriculum questions correctly.", (New-Object System.Drawing.Font("Segoe UI", [float]12, [System.Drawing.FontStyle]::Regular)), $muted, (New-Object System.Drawing.RectangleF([float]($px + 80), [float]($py + 260), [float]($pw - 160), 80)))

    # Blocked Apps Selection
    $yA = $py + 380
    $g.DrawString("Targeted Applications", (New-Object System.Drawing.Font("Segoe UI", [float]18, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 50), $yA)

    $apps = @(
        @{ Name = "Instagram"; Blocked = $true },
        @{ Name = "TikTok"; Blocked = $true },
        @{ Name = "YouTube"; Blocked = $true },
        @{ Name = "Snapchat"; Blocked = $true }
    )
    $yOff = $yA + 50
    foreach ($a in $apps) {
        $c = New-Object System.Drawing.Rectangle(($px + 50), $yOff, ($pw - 100), 80)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1E293B"))), $c)
        $g.DrawString($a.Name, (New-Object System.Drawing.Font("Segoe UI", [float]16, [System.Drawing.FontStyle]::Bold)), $white, [float]($px + 80), [float]($yOff + 25))
        
        # Switch ON
        $sw = New-Object System.Drawing.Rectangle(($px + $pw - 180), ($yOff + 20), 80, 40)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#4F46E5"))), $sw)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), ($px + $pw - 145), ($yOff + 22), 36, 36)
        
        $yOff += 105
    }
}
