# Builds email signatures in 4 heights (640px wide, 2x sharp) for everyone in staff.csv:
#   people/<id>/          640x200 (original)
#   people/<id>/h140/     640x140 (medium)
#   people/<id>/h120/     640x120 (compact)
#   people/<id>/h100/     640x100 (half height, 2-col contacts)
param([string]$BaseUrl = 'https://adundo-maseno.github.io/email-sig/')
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$assets = Join-Path $root 'assets'
$S = 2   # 2x render scale for sharp text/icons

$GREEN = '#4CA64F'; $BLUE = '#1574B4'; $NAVY = '#0F72AE'; $GREY = '#111111'; $TEXT = '#1F2A30'
$WEB = @{ text='www.agri-experience.com'; href='https://www.agri-experience.com' }
$LI  = @{ text='linkedin.com/company/agri-experience-ltd'; href='https://www.linkedin.com/company/agri-experience-ltd' }
$ADDR = @('The Watermark, Spring Court GF,', 'Ndege Road Karen, Nairobi, Kenya')
$ADDR1 = 'The Watermark, Spring Court GF, Ndege Road Karen, Nairobi, Kenya'

function C($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function New-G($bmp) {
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'; $g.TextRenderingHint = 'AntiAlias'; $g
}
function Tel($s) { 'tel:' + (($s -split '/')[0] -replace '[^\d+]', '') }
function Esc($s) { [System.Net.WebUtility]::HtmlEncode($s) }

$logo  = [System.Drawing.Bitmap]::new((Join-Path $assets 'logo.png'))
$frame = [System.Drawing.Bitmap]::new((Join-Path $assets 'frame-white.png'))
$icon  = @{}; foreach ($n in 'phone','mobile','web','linkedin','location') { $icon[$n] = [System.Drawing.Bitmap]::new((Join-Path $assets "icon-$n.png")) }

$variants = @(
  @{ slug='';     H=200; label='200px (Original)' },
  @{ slug='h140'; H=140; label='140px' },
  @{ slug='h120'; H=120; label='120px' },
  @{ slug='h100'; H=100; label='100px (Half)' }
)

function Build-Variant($p, $v) {
  $H = $v.H
  $sub = if ($v.slug) { "people/$($p.id)/$($v.slug)" } else { "people/$($p.id)" }
  $dir = Join-Path $root $sub; $tiles = Join-Path $dir 'tiles'
  if (Test-Path $tiles) { Remove-Item $tiles -Recurse -Force }
  New-Item -ItemType Directory -Force $tiles | Out-Null

  $bmp = [System.Drawing.Bitmap]::new(640*$S, $H*$S); $g = New-G $bmp
  $g.DrawImage($frame, 0, 0, 640*$S, $H*$S)

  $T = { param($text, $px, $style, $color, $x, $y)
    $f = [System.Drawing.Font]::new('Segoe UI', $px*$S, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString($text, $f, [System.Drawing.SolidBrush]::new((C $color)), $x*$S, $y*$S) }
  $Fit = { param($text, $px, $style, $maxW)
    while ($px -gt 8) {
      $f = [System.Drawing.Font]::new('Segoe UI', $px*$S, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel)
      if ($g.MeasureString($text, $f).Width / $S -le $maxW) { break }; $px -= 0.5
    }; $px }

  # Logo + divider geometry per height
  if ($H -eq 200) { $lh = 149; $lx = 30; $dx = 306; $tx = 330 }
  elseif ($H -eq 140) { $lh = 112; $lx = 26; $dx = 236; $tx = 256 }
  elseif ($H -eq 120) { $lh = 98;  $lx = 24; $dx = 208; $tx = 226 }
  else { $lh = 84; $lx = 22; $dx = 178; $tx = 194 }  # H=100

  $lw = [math]::Round($lh * $logo.Width / $logo.Height)
  $g.DrawImage($logo, $lx*$S, [int](($H-$lh)/2*$S), $lw*$S, $lh*$S)
  $g.FillRectangle([System.Drawing.SolidBrush]::new((C $GREEN)), $dx*$S, [int]($H*0.08)*$S, 3*$S, [int]($H*0.67)*$S)
  $g.FillRectangle([System.Drawing.SolidBrush]::new((C $BLUE)),  ($dx+7)*$S, [int]($H*0.17)*$S, 3*$S, [int]($H*0.74)*$S)

  $url = "$BaseUrl$sub/tiles/"
  $Crop = { param($name, $x, $y, $w, $h)
    $b = $bmp.Clone([System.Drawing.Rectangle]::new($x*$S, $y*$S, $w*$S, $h*$S), $bmp.PixelFormat)
    $b.Save((Join-Path $tiles "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose() }
  $Img = { param($file, $w, $h, $alt) "<img src=""$url$file.png"" width=""$w"" height=""$h"" alt=""$(Esc $alt)"" style=""display:block;border:0;width:${w}px;height:${h}px;"">" }
  $td = 'style="padding:0;margin:0;line-height:0;font-size:0;"'

  if ($H -eq 100) {
    # 2-column contacts so text stays crisp at half height
    $np = & $Fit $p.name 16 'Bold' 415;    & $T $p.name  $np 'Bold'    $NAVY $tx (5 + (16-$np)/2)
    $tp = & $Fit $p.title 11 'Regular' 415; & $T $p.title $tp 'Regular' $GREY $tx (24 + (11-$tp)/2)

    $col1 = $tx; $col2 = 402; $rowH = 18; $ico = 12
    $pairs = @(
      @{ y=42; l=$(if($p.phone){@{n='phone';t=$p.phone;h=(Tel $p.phone)}}else{$null}); r=$(if($p.mobile){@{n='mobile';t=$p.mobile;h=(Tel $p.mobile)}}else{$null}) },
      @{ y=60; l=@{n='web';t=$WEB.text;h=$WEB.href}; r=@{n='linkedin';t=$LI.text;h=$LI.href} }
    )
    foreach ($pr in $pairs) {
      if ($pr.l) {
        $g.DrawImage($icon[$pr.l.n], $col1*$S, ($pr.y+3)*$S, $ico*$S, $ico*$S)
        $fp = & $Fit $pr.l.t 10.5 'Regular' ($col2 - $col1 - 20)
        & $T $pr.l.t $fp 'Regular' $TEXT ($col1+16) ($pr.y+1)
      }
      if ($pr.r) {
        $g.DrawImage($icon[$pr.r.n], $col2*$S, ($pr.y+3)*$S, $ico*$S, $ico*$S)
        $fp = & $Fit $pr.r.t 10.5 'Regular' (622 - $col2 - 16)
        & $T $pr.r.t $fp 'Regular' $TEXT ($col2+16) ($pr.y+1)
      }
    }
    $g.DrawImage($icon['location'], $col1*$S, 81*$S, $ico*$S, $ico*$S)
    $ap = & $Fit $ADDR1 10.5 'Regular' (622 - $col1 - 16)
    & $T $ADDR1 $ap 'Regular' $TEXT ($col1+16) 79
    $g.Dispose()

    & $Crop 'top' 0 0 640 42
    $html = @("<table cellpadding=""0"" cellspacing=""0"" border=""0"" width=""640"" style=""border-collapse:collapse;width:640px;"">")
    $html += "<tr><td colspan=""3"" $td><a href=""$($WEB.href)"">$(& $Img 'top' 640 42 "Agri Experience - $($p.name), $($p.title)")</a></td></tr>"
    $idx = 0
    foreach ($pr in $pairs) {
      $idx++
      & $Crop "r$idx-s" 0 $pr.y $col1 $rowH
      & $Crop "r$idx-l" $col1 $pr.y ($col2-$col1) $rowH
      & $Crop "r$idx-r" $col2 $pr.y (640-$col2) $rowH
      $c1 = if ($pr.l) { "<a href=""$($pr.l.h)"">$(& $Img "r$idx-l" ($col2-$col1) $rowH $pr.l.t)</a>" } else { & $Img "r$idx-l" ($col2-$col1) $rowH '' }
      $c2 = if ($pr.r) { "<a href=""$($pr.r.h)"">$(& $Img "r$idx-r" (640-$col2) $rowH $pr.r.t)</a>" } else { & $Img "r$idx-r" (640-$col2) $rowH '' }
      $html += "<tr><td width=""$col1"" $td>$(& $Img "r$idx-s" $col1 $rowH '')</td><td width=""$($col2-$col1)"" $td>$c1</td><td width=""$(640-$col2)"" $td>$c2</td></tr>"
    }
    & $Crop 'bottom' 0 78 640 22
    $html += "<tr><td colspan=""3"" $td>$(& $Img 'bottom' 640 22 $ADDR1)</td></tr>"
    $html += '</table>'
  } else {
    # Single-column contacts (H = 200, 140, 120)
    $rows = @()
    if ($p.phone)  { $rows += @{ n='phone';    text=$p.phone;  href=(Tel $p.phone) } }
    if ($p.mobile) { $rows += @{ n='mobile';   text=$p.mobile; href=(Tel $p.mobile) } }
    $rows += @{ n='web'; text=$WEB.text; href=$WEB.href }
    $rows += @{ n='linkedin'; text=$LI.text; href=$LI.href }

    if ($H -eq 200) {
      $nPx=23; $nY=10; $tPx=14; $tY=42; $rPx=12.5; $ico=16; $rowH=20; $y0=74+(4-$rows.Count)*10; $twoLine=$true
    } elseif ($H -eq 140) {
      $nPx=18; $nY=5;  $tPx=12; $tY=26; $rPx=11;   $ico=13; $rowH=16; $y0=46+(4-$rows.Count)*8;  $twoLine=$true
    } else { # H=120
      $nPx=17; $nY=5;  $tPx=11; $tY=24; $rPx=10.5; $ico=12; $rowH=15; $y0=42+(4-$rows.Count)*7;  $twoLine=$false
    }
    for ($i = 0; $i -lt $rows.Count; $i++) { $rows[$i].y = $y0 + $rowH * $i }
    $addrY = $y0 + $rowH * $rows.Count

    $maxW = 620 - $tx
    $np = & $Fit $p.name $nPx 'Bold' $maxW;     & $T $p.name  $np 'Bold'    $NAVY $tx ($nY + ($nPx-$np)/2)
    $tp = & $Fit $p.title $tPx 'Regular' $maxW; & $T $p.title $tp 'Regular' $GREY $tx ($tY + ($tPx-$tp)/2)
    foreach ($r in $rows) {
      $g.DrawImage($icon[$r.n], ($tx+2)*$S, ($r.y+2)*$S, $ico*$S, $ico*$S)
      $fp = & $Fit $r.text $rPx 'Regular' ($maxW - $ico - 8)
      & $T $r.text $fp 'Regular' $TEXT ($tx+$ico+8) $r.y
    }
    $g.DrawImage($icon['location'], ($tx+2)*$S, ($addrY+2)*$S, $ico*$S, $ico*$S)
    if ($twoLine) {
      $step = if ($H -eq 200) { 16 } else { 13 }
      & $T $ADDR[0] $rPx 'Regular' $TEXT ($tx+$ico+8) $addrY
      & $T $ADDR[1] $rPx 'Regular' $TEXT ($tx+$ico+8) ($addrY+$step)
    } else {
      $ap = & $Fit $ADDR1 $rPx 'Regular' ($maxW - $ico - 8)
      & $T $ADDR1 $ap 'Regular' $TEXT ($tx+$ico+8) $addrY
    }
    $g.Dispose()

    $split = $tx + $ico + 6
    $top = $rows[0].y
    & $Crop 'top' 0 0 640 $top
    $html = @("<table cellpadding=""0"" cellspacing=""0"" border=""0"" width=""640"" style=""border-collapse:collapse;width:640px;"">")
    $html += "<tr><td colspan=""2"" $td><a href=""$($WEB.href)"">$(& $Img 'top' 640 $top "Agri Experience - $($p.name), $($p.title)")</a></td></tr>"
    foreach ($r in $rows) {
      & $Crop "$($r.n)-l" 0 $r.y $split $rowH; & $Crop "$($r.n)-r" $split $r.y (640-$split) $rowH
      $html += "<tr><td width=""$split"" $td>$(& $Img "$($r.n)-l" $split $rowH '')</td><td width=""$(640-$split)"" $td><a href=""$($r.href)"">$(& $Img "$($r.n)-r" (640-$split) $rowH $r.text)</a></td></tr>"
    }
    & $Crop 'bottom' 0 $addrY 640 ($H-$addrY)
    $html += "<tr><td colspan=""2"" $td>$(& $Img 'bottom' 640 ($H-$addrY) $ADDR1)</td></tr>"
    $html += '</table>'
  }

  $bmp.Save((Join-Path $dir 'signature.png'), [System.Drawing.Imaging.ImageFormat]::Png)
  $small = [System.Drawing.Bitmap]::new(640, $H); $gs = New-G $small
  $gs.DrawImage($bmp, 0, 0, 640, $H); $gs.Dispose()
  $small.Save((Join-Path $dir 'signature-640.png'), [System.Drawing.Imaging.ImageFormat]::Png); $small.Dispose()
  $bmp.Dispose()

  Set-Content (Join-Path $dir 'index.html') @"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>$(Esc $p.name) - email signature (${H}px)</title></head>
<body style="margin:24px;font-family:Segoe UI,Arial,sans-serif;color:#333;">
<!--SIG-->
$($html -join "`n")
<!--/SIG-->
</body></html>
"@ -Encoding UTF8
}

$staff = Import-Csv (Join-Path $root 'staff.csv') -Encoding UTF8
$cards = @()
foreach ($p in $staff) {
  $links = @()
  foreach ($v in $variants) {
    Build-Variant $p $v
    $href = if ($v.slug) { "people/$($p.id)/$($v.slug)/" } else { "people/$($p.id)/" }
    $links += "<a href=""$href"" style=""margin-right:12px;color:#1574B4;"">$($v.label)</a>"
  }
  $cards += "<li style=""margin:0 0 22px;""><strong style=""font-size:16px;color:#1E4D5C;"">$(Esc $p.name)</strong> <span style=""color:#6B7B82;"">- $(Esc $p.title)</span><div style=""margin:6px 0;"">$($links -join '')</div><a href=""people/$($p.id)/h100/""><img src=""people/$($p.id)/h100/signature-640.png"" width=""320"" style=""border:1px solid #eee;""></a></li>"
  "built: $($p.id) (4 heights)"
}

Set-Content (Join-Path $root 'index.html') @"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Agri Experience email signatures</title></head>
<body style="margin:24px;font-family:Segoe UI,Arial,sans-serif;">
<h2 style="color:#1E4D5C;">Agri Experience email signatures</h2>
<p style="color:#666;">Pick a height for your name (all are 640px wide), then press Ctrl+A, Ctrl+C and paste into Gmail.</p>
<ul style="list-style:none;padding:0;">
$($cards -join "`n")
</ul></body></html>
"@ -Encoding UTF8
'done'
