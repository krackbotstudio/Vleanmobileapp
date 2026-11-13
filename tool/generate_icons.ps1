Add-Type -AssemblyName System.Drawing

$sourcePath = "$PSScriptRoot\..\assets\vclean-logo.png"
$source = [System.Drawing.Image]::FromFile($sourcePath)

function Save-Resized {
    param (
        [System.Drawing.Image]$img,
        [int]$targetWidth,
        [int]$targetHeight,
        [string]$outPath,
        [float]$scale = 1.0,
        [bool]$circleBg = $false,
        [bool]$whiteBg = $false
    )

    $dir = [System.IO.Path]::GetDirectoryName($outPath)
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $bmp = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($whiteBg) {
        $g.Clear([System.Drawing.Color]::White)
    } elseif ($circleBg) {
        $g.Clear([System.Drawing.Color]::Transparent)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $g.FillEllipse($brush, 0, 0, $targetWidth, $targetHeight)
        $brush.Dispose()
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
    }

    # Compute scaled size maintaining aspect ratio
    $logoW = [int]($targetWidth * $scale)
    $logoH = [int]($targetHeight * $scale)
    $x = [int](($targetWidth - $logoW) / 2)
    $y = [int](($targetHeight - $logoH) / 2)

    $g.DrawImage($img, $x, $y, $logoW, $logoH)
    $g.Dispose()

    # Save as PNG
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created: $outPath ($targetWidth x $targetHeight)"
}

$resDir = "$PSScriptRoot\..\android\app\src\main\res"

# 1. Android Adaptive Icons (Foreground - transparent background, logo scaled to ~72% for safe zone)
$androidForegrounds = @{
    "mipmap-mdpi" = 108
    "mipmap-hdpi" = 162
    "mipmap-xhdpi" = 216
    "mipmap-xxhdpi" = 324
    "mipmap-xxxhdpi" = 432
}

foreach ($kv in $androidForegrounds.GetEnumerator()) {
    $out = "$resDir\$($kv.Key)\ic_launcher_foreground.png"
    Save-Resized -img $source -targetWidth $kv.Value -targetHeight $kv.Value -outPath $out -scale 0.72 -whiteBg $false
}

# 2. Android Legacy Icons (White square with logo)
$androidLegacy = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($kv in $androidLegacy.GetEnumerator()) {
    $out = "$resDir\$($kv.Key)\ic_launcher.png"
    Save-Resized -img $source -targetWidth $kv.Value -targetHeight $kv.Value -outPath $out -scale 0.85 -whiteBg $true

    $outRound = "$resDir\$($kv.Key)\ic_launcher_round.png"
    Save-Resized -img $source -targetWidth $kv.Value -targetHeight $kv.Value -outPath $outRound -scale 0.74 -circleBg $true
}

# 3. iOS App Icons
$iosDir = "$PSScriptRoot\..\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosDir) {
    $iosSizes = @{
        "Icon-App-20x20@1x.png" = 20
        "Icon-App-20x20@2x.png" = 40
        "Icon-App-20x20@3x.png" = 60
        "Icon-App-29x29@1x.png" = 29
        "Icon-App-29x29@2x.png" = 58
        "Icon-App-29x29@3x.png" = 87
        "Icon-App-40x40@1x.png" = 40
        "Icon-App-40x40@2x.png" = 80
        "Icon-App-40x40@3x.png" = 120
        "Icon-App-60x60@2x.png" = 120
        "Icon-App-60x60@3x.png" = 180
        "Icon-App-76x76@1x.png" = 76
        "Icon-App-76x76@2x.png" = 152
        "Icon-App-83.5x83.5@2x.png" = 167
        "Icon-App-1024x1024@1x.png" = 1024
    }
    foreach ($kv in $iosSizes.GetEnumerator()) {
        $out = "$iosDir\$($kv.Key)"
        Save-Resized -img $source -targetWidth $kv.Value -targetHeight $kv.Value -outPath $out -scale 0.85 -whiteBg $true
    }
}

# 4. Web Icons
$webDir = "$PSScriptRoot\..\web"
if (Test-Path $webDir) {
    Save-Resized -img $source -targetWidth 192 -targetHeight 192 -outPath "$webDir\icons\Icon-192.png" -scale 0.85 -whiteBg $true
    Save-Resized -img $source -targetWidth 512 -targetHeight 512 -outPath "$webDir\icons\Icon-512.png" -scale 0.85 -whiteBg $true
    Save-Resized -img $source -targetWidth 192 -targetHeight 192 -outPath "$webDir\icons\Icon-maskable-192.png" -scale 0.72 -whiteBg $true
    Save-Resized -img $source -targetWidth 512 -targetHeight 512 -outPath "$webDir\icons\Icon-maskable-512.png" -scale 0.72 -whiteBg $true
    Save-Resized -img $source -targetWidth 64 -targetHeight 64 -outPath "$webDir\favicon.png" -scale 0.85 -whiteBg $true
}

$source.Dispose()
Write-Host "All launcher icons generated successfully!"
