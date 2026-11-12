# Builds the Agri Experience email signature assets:
#   assets/logo.png, assets/frame.jpg, assets/icon-*.png, signature.png (2x, 1280x400)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src  = 'C:/Users/User/.gemini/antigravity/brain/173ae87e-5362-494d-aca1-227f824720e0/.user_uploaded/'
$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Force $assets | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Trim {
  public static Rectangle Bounds(Bitmap b) {
    var d = b.LockBits(new Rectangle(0,0,b.Width,b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var px = new byte[d.Stride*b.Height]; Marshal.Copy(d.Scan0, px, 0, px.Length); b.UnlockBits(d);
    int x0=b.Width,y0=b.Height,x1=0,y1=0;
    for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) if(px[y*d.Stride+x*4+3]>20){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; }
    return Rectangle.FromLTRB(x0,y0,x1+1,y1+1);
  }
}
"@

function New-G($bmp) {
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'; $g.TextRenderingHint = 'AntiAlias'
  return $g
}
function C($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

$GREEN = '#4CA64F'; $BLUE = '#1574B4'; $NAVY = '#1E4D5C'; $GREY = '#6B7B82'; $TEXT = '#1F2A30'

# --- Logo (trimmed) ---
$logoSrc = [System.Drawing.Bitmap]::new($src + 'media_1794503646868_8f89a3d2.png')
$r = [Trim]::Bounds($logoSrc)
$logo = $logoSrc.Clone($r, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$logo.Save((Join-Path $assets 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
"logo trimmed: $($logo.Width)x$($logo.Height)"

# --- Frame ---
Copy-Item ($src + 'media_1794503646849_d380c888.jpg') (Join-Path $assets 'frame.jpg') -Force
$frame = [System.Drawing.Bitmap]::new((Join-Path $assets 'frame.jpg'))

# --- Icons (48px = 16px @3x) ---
$icons = @(
  @{ name='phone';    color=$BLUE;  font='Segoe MDL2 Assets'; glyph=[string][char]0xE717; size=26; style='Regular' },
  @{ name='mobile';   color=$GREEN; font='Segoe MDL2 Assets'; glyph=[string][char]0xE8EA; size=27; style='Regular' },
  @{ name='web';      color=$GREEN; font='Arial';             glyph='W';  size=24; style='Bold' },
  @{ name='linkedin'; color=$BLUE;  font='Arial';             glyph='in'; size=23; style='Bold' },
  @{ name='location'; color=$GREEN; font='Segoe MDL2 Assets'; glyph=[string][char]0xE81D; size=28; style='Regular' }
)
$sf = [System.Drawing.StringFormat]::new(); $sf.Alignment='Center'; $sf.LineAlignment='Center'
foreach ($i in $icons) {
  $b = [System.Drawing.Bitmap]::new(48,48); $g = New-G $b
  $g.FillEllipse([System.Drawing.SolidBrush]::new((C $i.color)), 0, 0, 47, 47)
  $f = [System.Drawing.Font]::new($i.font, $i.size, [System.Drawing.FontStyle]$i.style, [System.Drawing.GraphicsUnit]::Pixel)
  if ($i.name -eq 'location') {
    # hand-drawn map pin: round head tapering to a point, with a hole
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc(14, 9, 20, 20, 150, 240)
    $path.AddLine(33.5, 23.5, 24, 39); $path.AddLine(24, 39, 14.5, 23.5); $path.CloseFigure()
    $g.FillPath([System.Drawing.Brushes]::White, $path)
    $g.FillEllipse([System.Drawing.SolidBrush]::new((C $i.color)), 19.5, 14.5, 9, 9)
  } else {
    $g.DrawString($i.glyph, $f, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new(0,1,48,48), $sf)
  }
  $g.Dispose(); $b.Save((Join-Path $assets "icon-$($i.name).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $i.bmp = $b
}

# --- Composite signature.png (layout in 640x200 units, rendered at 2x) ---
$S = 2
$out = [System.Drawing.Bitmap]::new(640*$S, 200*$S); $g = New-G $out
$g.DrawImage($frame, 0, 0, 640*$S, 200*$S)
$lw = 236; $lh = [math]::Round($lw * $logo.Height / $logo.Width)
$g.DrawImage($logo, 30*$S, [int]((200-$lh)/2*$S), $lw*$S, $lh*$S)
$g.FillRectangle([System.Drawing.SolidBrush]::new((C $GREEN)), 306*$S, 16*$S, 3*$S, 134*$S)
$g.FillRectangle([System.Drawing.SolidBrush]::new((C $BLUE)),  313*$S, 34*$S, 3*$S, 148*$S)

function T($text, $family, $px, $style, $color, $x, $y) {
  $f = [System.Drawing.Font]::new($family, $px*$S, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($text, $f, [System.Drawing.SolidBrush]::new((C $color)), $x*$S, $y*$S)
}
$tx = 330
T 'Ronald Misigo'  'Segoe UI' 23 'Bold'    $NAVY $tx 10
T 'Technical Lead' 'Segoe UI' 14 'Regular' $GREY $tx 42
$rows = @(
  @('phone',    '+254(20)2626888 / 719554154'),
  @('mobile',   '+254727246973'),
  @('web',      'www.agri-experience.com'),
  @('linkedin', 'linkedin.com/company/agri-experience-ltd'),
  @('location', 'The Watermark, Spring Court GF,')
)
$y = 74
foreach ($row in $rows) {
  $ico = ($icons | ? name -eq $row[0]).bmp
  $g.DrawImage($ico, ($tx+2)*$S, ($y+2)*$S, 16*$S, 16*$S)
  T $row[1] 'Segoe UI' 12.5 'Regular' $TEXT ($tx+25) $y
  $y += 20
}
T 'Ndege Road Karen, Nairobi, Kenya' 'Segoe UI' 12.5 'Regular' $TEXT ($tx+25) ($y-4)
$g.Dispose()
$out.Save((Join-Path $root 'signature.png'), [System.Drawing.Imaging.ImageFormat]::Png)
'done'

