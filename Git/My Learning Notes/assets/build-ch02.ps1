$name = "02-git-branches-and-merge"
$base = "F:\Claude code\Git\My Learning Notes"
$sp = Split-Path $PSCommandPath
$img = "C:\Users\Lemnovo\AppData\Local\Temp\claude\f--Claude-code\33c75ad6-031d-4526-b474-0ab5ffe8b5f8\images"   # pasted chat images (session-specific; already-copied assets are kept)
$utf8 = New-Object Text.UTF8Encoding $false

# ---- screenshots -> track assets ----
$assets = "$base\Screenshots\assets\$name"
New-Item -ItemType Directory -Force $assets | Out-Null
117..161 | ForEach-Object { if (Test-Path "$img\$_.png") { Copy-Item "$img\$_.png" ("$assets\{0:D2}.png" -f ($_ - 116)) -Force } }

# ---- notes HTML from the AI template ----
$t = [IO.File]::ReadAllText("$base\assets\git-notes-template.html")
$md = [IO.File]::ReadAllText("$base\$name.md")
$out = $t.Replace('{{TITLE}}','Git Branches & Merge').Replace('{{SHORT}}','Ch 02 · Branches & Merge').Replace('{{PDFNAME}}',"$name.pdf")
$out = $out.Replace('{{MARKED}}',[IO.File]::ReadAllText("$base\assets\marked.js")).Replace('{{HLJS}}',[IO.File]::ReadAllText("$base\assets\hljs.js"))
$out = $out.Replace('{{MD}}',$md.TrimEnd())
[IO.File]::WriteAllText("$base\PDF\$name.html", $out, $utf8)

# ---- gallery ----
$C = @(
 'Git branches &mdash; why and what',
 'Branch naming conventions',
 'Atomic development',
 'Key idea: one branch one purpose',
 'Visualizing branches &mdash; pointers, feature branch, parallel development',
 'git init',
 'chore: initialize application (0e3ffcd)',
 'Commit without git add &rarr; no changes added',
 'feat: add footer section',
 'git log --oneline &mdash; 3 commits',
 'cat app.txt',
 'Full git log',
 'git log --oneline',
 'git branch feature/login + git checkout',
 'git branch &mdash; * current',
 'Cannot delete the current branch',
 'Switch to master, then git branch -d',
 'git checkout -b feature/login',
 'Switched to a new branch',
 'HEAD -> feature/login, master',
 'Switching branches &mdash; only HEAD moves',
 'feature/login sees app.txt',
 'feat: implement login functionality (13b779a)',
 'login exists only on feature/login',
 'Git merge &mdash; fast-forward vs three-way',
 'git merge feature/login &rarr; Fast-forward',
 'git reflog &mdash; merge feature/login: Fast-forward',
 'Demo: branch creation &amp; fast-forward merge',
 'git checkout -b bugfix/typo from the tip',
 'log --oneline on bugfix/typo',
 'git checkout -b bugfix/typo 0e3ffcd',
 'Only the first commit in history',
 'app.txt has one line',
 'Delete and recreate bugfix/typo from master',
 'All three branches at 13b779a',
 'fix: correct footer typo (3fc7beb)',
 'bugfix/typo one commit ahead',
 'Demo: three-way merge plan',
 'style: improve footer spacing on master (d40c83f)',
 'Different new files per branch',
 'git log --oneline --all',
 'git merge bugfix/typo &rarr; ort strategy',
 'Merge commit b18b077',
 'git show &rarr; Merge: d40c83f 3fc7beb',
 'git log --oneline --graph'
)
$n = $C.Count; $blocks = @()
for ($i = 0; $i -lt $n; $i++) {
  $nn = '{0:D2}' -f ($i + 1)
  $blocks += "<section class=`"shot`"><div class=`"hd`"><span class=`"num`">$nn<small>/ $n</small></span><span class=`"cap`">$($C[$i])</span></div><div class=`"frame`"><img src=`"assets/$name/$nn.png`"></div></section>"
}
$g = @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Screenshots &mdash; Git Branches &amp; Merge</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  @page { size: A4 landscape; margin: 10mm 12mm 12mm;
    @bottom-right { content: "Page " counter(page); font: 600 8pt Inter, sans-serif; color: #7c3aed; }
    @bottom-left { content: "Git Track \00B7  Ch 02 screenshots"; font: 500 8pt Inter, sans-serif; color: #9a9cb8; } }
  @page :first { margin: 0; @bottom-right { content: none; } @bottom-left { content: none; } }
  html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  body { margin: 0; font-family: Inter, "Segoe UI", sans-serif; color: #1b1d3a; }
  code { font-family: "JetBrains Mono", Consolas, monospace; font-size: .9em; background: #efedff; color: #5b21b6; padding: 0 4px; border-radius: 4px; }
  .cover { height: 210mm; padding: 30mm 24mm; color: #fff; display: flex; flex-direction: column; break-after: page;
    background: radial-gradient(circle at 85% 15%, rgba(45,212,191,.5) 0, rgba(45,212,191,0) 38%), linear-gradient(140deg, #1e1b4b 0%, #3730a3 45%, #6d28d9 100%); }
  .cover .k { font-size: 10pt; font-weight: 700; letter-spacing: .18em; text-transform: uppercase; color: #c7d2fe; }
  .cover h1 { font-size: 34pt; font-weight: 800; margin: 18mm 0 4mm; line-height: 1.1; }
  .cover p { font-size: 12pt; color: #ddd6fe; margin: 0; }
  .cover .big { margin-top: auto; font-size: 64pt; font-weight: 800; color: rgba(255,255,255,.9); }
  .cover .big small { font-size: 14pt; font-weight: 600; color: #c4b5fd; margin-left: 10px; }
  .shot { break-after: page; break-inside: avoid; padding-top: 2mm; }
  .shot:last-child { break-after: auto; }
  .hd { display: flex; align-items: center; gap: 14px; padding: 8px 14px; border-radius: 12px; margin-bottom: 8px;
    background: linear-gradient(90deg, #eef0ff, #f7f2ff); border: 1px solid #e4e2f3; }
  .num { font-weight: 800; font-size: 15pt; color: #fff; background: linear-gradient(135deg, #4f46e5, #7c3aed); padding: 3px 12px; border-radius: 9px; white-space: nowrap; }
  .num small { font-size: 8.5pt; font-weight: 600; opacity: .8; margin-left: 3px; }
  .cap { font-size: 11pt; font-weight: 600; }
  .frame { text-align: center; }
  .frame img { max-width: 100%; max-height: 158mm; border-radius: 10px; border: 1px solid #e4e2f3; box-shadow: 0 8px 22px rgba(27,29,58,.14); }
</style></head><body>
<section class="cover"><div class="k">Git Track &middot; Screenshots</div>
<h1>Chapter 02 &mdash; Git Branches &amp; Merge<br>Pointers, HEAD, Fast-forward &amp; Three-way Merge</h1>
<p>Git Masterclass &middot; Part 1 &middot; stills from the session, in order &middot; 2026-10-13</p>
<div class="big">$n<small>screenshots</small></div></section>
$($blocks -join "`n")
</body></html>
"@
[IO.File]::WriteAllText("$base\Screenshots\$name-screenshots.html", $g, $utf8)
"assets=$((Get-ChildItem $assets).Count) md-scripts-close=$([regex]::Matches($md,'</script').Count)"

# ---- PDFs ----
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
foreach ($j in @(@("$base\PDF\$name.html","$base\PDF\$name.pdf"),@("$base\Screenshots\$name-screenshots.html","$base\Screenshots\$name-screenshots.pdf"))) {
  Start-Process -FilePath $edge -ArgumentList @('--headless','--disable-gpu','--no-pdf-header-footer','--virtual-time-budget=20000',"--print-to-pdf=`"$($j[1])`"","`"$(([Uri]$j[0]).AbsoluteUri)`"") -Wait
  "{0}  {1:N0} bytes" -f (Split-Path $j[1] -Leaf), (Get-Item $j[1]).Length
}
# preview screenshots of the notes page for a visual check
Start-Process -FilePath $edge -ArgumentList @('--headless','--disable-gpu','--hide-scrollbars','--window-size=900,4200','--virtual-time-budget=15000',"--screenshot=`"$sp\preview1.png`"","`"$(([Uri]"$base\PDF\$name.html").AbsoluteUri)`"") -Wait