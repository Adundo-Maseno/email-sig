# Builds email signatures for everyone in staff.csv.
#   people/<id>/signature.png        2x image (1280x400)
#   people/<id>/signature-640.png    single image for direct upload to Gmail/Outlook
#   people/<id>/tiles/*.png          sliced images (frame baked in) for the clickable Gmail version
#   people/<id>/index.html           clickable Gmail signature - open it, Ctrl+A, Ctrl+C, paste into Gmail
#   index.html                       directory page linking to everyone's signature
# Empty phone/mobile cells are skipped. Then: git add -A; git commit -m "..."; git push
param([string]$BaseUrl = 'https://adundo-maseno.github.io/email-sig/')
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$assets = Join-Path $root 'assets'
$S = 2   # render scale

$GREEN = '#4CA64F'; $BLUE = '#1574B4'; $NAVY = '#1E4D5C'; $GREY = '#6B7B82'; $TEXT = '#1F2A30'
$WEB = @{ text = 'www.agri-experience.com'; href = 'https://www.agri-experience.com' }
$LI = @{ text = 'linkedin.com/company/agri-experience-ltd'; href = 'https://www.linkedin.com/company/agri-experience-ltd' }
$ADDR = @('The Watermark, Spring Court GF,', 'Ndege Road Karen, Nairobi, Kenya')

function C($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function New-G($bmp) {
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'; $g.TextRenderingHint = 'AntiAlias'; $g
}
function Tel($s) { 'tel:' + (($s -split '/')[0] -replace '[^\d+]', '') }
function Esc($s) { [System.Net.WebUtility]::HtmlEncode($s) }

$logo = [System.Drawing.Bitmap]::new((Join-Path $assets 'logo.png'))
$frame = [System.Drawing.Bitmap]::new((Join-Path $assets 'frame.jpg'))
$icon = @{}; foreach ($n in 'phone', 'mobile', 'web', 'linkedin', 'location') { $icon[$n] = [System.Drawing.Bitmap]::new((Join-Path $assets "icon-$n.png")) }

$staff = Import-Csv (Join-Path $root 'staff.csv')
$cards = @()
foreach ($p in $staff) {
  $dir = Join-Path $root "people/$($p.id)"; $tiles = Join-Path $dir 'tiles'
  if (Test-Path $tiles) { Remove-Item $tiles -Recurse -Force }
  New-Item -ItemType Directory -Force $tiles | Out-Null

  # contact rows (y in 640x200 units)
  $rows = @()
  if ($p.phone) { $rows += @{ n = 'phone'; text = $p.phone; href = (Tel $p.phone) } }
  if ($p.mobile) { $rows += @{ n = 'mobile'; text = $p.mobile; href = (Tel $p.mobile) } }
  $rows += @{ n = 'web'; text = $WEB.text; href = $WEB.href }
  $rows += @{ n = 'linkedin'; text = $LI.text; href = $LI.href }
  $y0 = 74 + (4 - $rows.Count) * 10   # keep block vertically balanced if rows are skipped
  for ($i = 0; $i -lt $rows.Count; $i++) { $rows[$i].y = $y0 + 20 * $i }
  $addrY = $y0 + 20 * $rows.Count

  # ---- render ----
  $bmp = [System.Drawing.Bitmap]::new(640 * $S, 200 * $S); $g = New-G $bmp
  $g.DrawImage($frame, 0, 0, 640 * $S, 200 * $S)
  $lw = 236; $lh = [math]::Round($lw * $logo.Height / $logo.Width)
  $g.DrawImage($logo, 30 * $S, [int]((200 - $lh) / 2 * $S), $lw * $S, $lh * $S)
  $g.FillRectangle([System.Drawing.SolidBrush]::new((C $GREEN)), 306 * $S, 16 * $S, 3 * $S, 134 * $S)
  $g.FillRectangle([System.Drawing.SolidBrush]::new((C $BLUE)), 313 * $S, 34 * $S, 3 * $S, 148 * $S)
  $T = { param($text, $px, $style, $color, $x, $y)
    $f = [System.Drawing.Font]::new('Segoe UI', $px * $S, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString($text, $f, [System.Drawing.SolidBrush]::new((C $color)), $x * $S, $y * $S) }
  $Fit = { param($text, $px, $style, $maxW)   # shrink long names/titles to fit
    while ($px -gt 9) {
      $f = [System.Drawing.Font]::new('Segoe UI', $px * $S, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel)
      if ($g.MeasureString($text, $f).Width / $S -le $maxW) { break }; $px -= 0.5 
    }; $px }
  $tx = 330
  $np = & $Fit $p.name 23 'Bold' 290; & $T $p.name  $np 'Bold'    $NAVY $tx (10 + (23 - $np) / 2)
  $tp = & $Fit $p.title 14 'Regular' 280; & $T $p.title $tp 'Regular' $GREY $tx (42 + (14 - $tp) / 2)
  foreach ($r in $rows) {
    $g.DrawImage($icon[$r.n], ($tx + 2) * $S, ($r.y + 2) * $S, 16 * $S, 16 * $S)
    & $T $r.text 12.5 'Regular' $TEXT ($tx + 25) $r.y
  }
  $g.DrawImage($icon['location'], ($tx + 2) * $S, ($addrY + 2) * $S, 16 * $S, 16 * $S)
  & $T $ADDR[0] 12.5 'Regular' $TEXT ($tx + 25) $addrY
  & $T $ADDR[1] 12.5 'Regular' $TEXT ($tx + 25) ($addrY + 16)
  $g.Dispose()
  $bmp.Save((Join-Path $dir 'signature.png'), [System.Drawing.Imaging.ImageFormat]::Png)

  $small = [System.Drawing.Bitmap]::new(640, 200); $gs = New-G $small
  $gs.DrawImage($bmp, 0, 0, 640, 200); $gs.Dispose()
  $small.Save((Join-Path $dir 'signature-640.png'), [System.Drawing.Imaging.ImageFormat]::Png); $small.Dispose()

  # ---- tiles + clickable HTML ----
  $url = "$BaseUrl" + "people/$($p.id)/tiles/"
  $split = 352
  $Crop = { param($name, $x, $y, $w, $h)
    $b = $bmp.Clone([System.Drawing.Rectangle]::new($x * $S, $y * $S, $w * $S, $h * $S), $bmp.PixelFormat)
    $b.Save((Join-Path $tiles "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose() }
  $Img = { param($file, $w, $h, $alt) "<img src=""$url$file.png"" width=""$w"" height=""$h"" alt=""$(Esc $alt)"" style=""display:block;border:0;width:${w}px;height:${h}px;"">" }
  $td = 'style="padding:0;margin:0;line-height:0;font-size:0;"'
  $top = $rows[0].y
  & $Crop 'top' 0 0 640 $top
  $h = @("<table cellpadding=""0"" cellspacing=""0"" border=""0"" width=""640"" style=""border-collapse:collapse;width:640px;"">")
  $h += "<tr><td colspan=""2"" $td><a href=""$($WEB.href)"">$(& $Img 'top' 640 $top "Agri Experience - $($p.name), $($p.title)")</a></td></tr>"
  foreach ($r in $rows) {
    & $Crop "$($r.n)-l" 0 $r.y $split 20; & $Crop "$($r.n)-r" $split $r.y (640 - $split) 20
    $h += "<tr><td width=""$split"" $td>$(& $Img "$($r.n)-l" $split 20 '')</td><td width=""$(640-$split)"" $td><a href=""$($r.href)"">$(& $Img "$($r.n)-r" (640-$split) 20 $r.text)</a></td></tr>"
  }
  & $Crop 'bottom' 0 $addrY 640 (200 - $addrY)
  $h += "<tr><td colspan=""2"" $td>$(& $Img 'bottom' 640 (200-$addrY) ($ADDR -join ' '))</td></tr>"
  $h += '</table>'
  $page = @"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>$(Esc $p.name) - email signature</title></head>
<body style="margin:24px;font-family:Segoe UI,Arial,sans-serif;color:#333;">
<!--SIG-->
$($h -join "`n")
<!--/SIG-->
</body></html>
"@
  Set-Content (Join-Path $dir 'index.html') $page -Encoding UTF8
  $bmp.Dispose()
  $cards += "<li style=""margin:0 0 18px;""><a href=""people/$($p.id)/"" style=""font-size:16px;color:#1E4D5C;font-weight:600;"">$(Esc $p.name)</a> <span style=""color:#6B7B82;"">- $(Esc $p.title)</span><br><a href=""people/$($p.id)/""><img src=""people/$($p.id)/signature-640.png"" width=""320"" style=""margin-top:6px;border:1px solid #eee;""></a></li>"
  "built: $($p.id)"
}

Set-Content (Join-Path $root 'index.html') @"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Agri Experience email signatures</title></head>
<body style="margin:24px;font-family:Segoe UI,Arial,sans-serif;">
<h2 style="color:#1E4D5C;">Agri Experience email signatures</h2>
<p style="color:#666;">Click your name, then follow the instructions on that page.</p>
<ul style="list-style:none;padding:0;">
$($cards -join "`n")
</ul></body></html>
"@ -Encoding UTF8
'done'

