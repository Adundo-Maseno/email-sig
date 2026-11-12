# Builds Gmail-safe signature files (Gmail strips background images in signatures).
#   gmail/signature-640.png  -> single image to upload directly in Gmail
#   gmail/tiles/*.png + gmail/signature-gmail.html -> sliced, clickable version (needs hosted images)
param([string]$BaseUrl = 'https://YOUR-HOST/email-sig/tiles/')
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$gm = Join-Path $root 'gmail'; $tiles = Join-Path $gm 'tiles'
New-Item -ItemType Directory -Force $tiles | Out-Null
$full = [System.Drawing.Bitmap]::new((Join-Path $root 'signature.png'))   # 1280x400 (2x)
$S = 2

# 1) Single 640x200 image
$small = [System.Drawing.Bitmap]::new(640, 200)
$g = [System.Drawing.Graphics]::FromImage($small)
$g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.DrawImage($full, 0, 0, 640, 200); $g.Dispose()
$small.Save((Join-Path $gm 'signature-640.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# 2) Tiles (coordinates in 640x200 units). Split column at x=352 (text start).
function Crop($name, $x, $y, $w, $h) {
  $b = $full.Clone([System.Drawing.Rectangle]::new($x*$S, $y*$S, $w*$S, $h*$S), $full.PixelFormat)
  $b.Save((Join-Path $tiles "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
$split = 352
$rows = @(
  @{ n='phone';    y=74;  h=20; href='tel:+254202626888';                               alt='+254(20)2626888 / 719554154' },
  @{ n='mobile';   y=94;  h=20; href='tel:+254727246973';                               alt='+254727246973' },
  @{ n='web';      y=114; h=20; href='https://www.agri-experience.com';                 alt='www.agri-experience.com' },
  @{ n='linkedin'; y=134; h=20; href='https://www.linkedin.com/company/agri-experience-ltd'; alt='linkedin.com/company/agri-experience-ltd' }
)
Crop 'top' 0 0 640 74
foreach ($r in $rows) { Crop "$($r.n)-l" 0 $r.y $split $r.h; Crop "$($r.n)-r" $split $r.y (640-$split) $r.h }
Crop 'bottom' 0 154 640 46

$img = { param($file, $w, $h, $alt) "<img src=""$BaseUrl$file.png"" width=""$w"" height=""$h"" alt=""$alt"" style=""display:block;border:0;width:${w}px;height:${h}px;"">" }
$td  = 'style="padding:0;margin:0;line-height:0;font-size:0;"'
$html = @("<table cellpadding=""0"" cellspacing=""0"" border=""0"" width=""640"" style=""border-collapse:collapse;width:640px;"">")
$html += "<tr><td colspan=""2"" $td><a href=""https://www.agri-experience.com"">$(& $img 'top' 640 74 'Agri Experience - Ronald Misigo, Technical Lead')</a></td></tr>"
foreach ($r in $rows) {
  $html += "<tr><td width=""$split"" $td>$(& $img "$($r.n)-l" $split $r.h '')</td><td width=""$(640-$split)"" $td><a href=""$($r.href)"">$(& $img "$($r.n)-r" (640-$split) $r.h $r.alt)</a></td></tr>"
}
$html += "<tr><td colspan=""2"" $td>$(& $img 'bottom' 640 46 'The Watermark, Spring Court GF, Ndege Road Karen, Nairobi, Kenya')</td></tr>"
$html += '</table>'
Set-Content (Join-Path $gm 'signature-gmail.html') ("<!DOCTYPE html><html><head><meta charset=""utf-8""><title>Gmail signature</title></head><body style=""margin:20px;"">`n" + ($html -join "`n") + "`n</body></html>") -Encoding UTF8
'done'

