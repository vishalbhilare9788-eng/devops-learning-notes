$name = "03-production-grade-rag"
$base = "F:\Claude code\AI\My Learning Notes"
$sp = Split-Path $PSCommandPath
$img = "C:\Users\Lemnovo\AppData\Local\Temp\claude\f--Claude-code\33c75ad6-031d-4526-b474-0ab5ffe8b5f8\images"   # pasted chat images (session-specific; already-copied assets are kept)
$utf8 = New-Object Text.UTF8Encoding $false

# ---- screenshots -> track assets ----
$assets = "$base\Screenshots\assets\$name"
New-Item -ItemType Directory -Force $assets | Out-Null
1..69 | ForEach-Object { if (Test-Path "$img\$_.png") { Copy-Item "$img\$_.png" ("$assets\{0:D2}.png" -f ($_)) -Force } }

# ---- notes HTML from the AI template ----
$t = [IO.File]::ReadAllText("$base\assets\ai-notes-template.html")
$md = [IO.File]::ReadAllText("$base\$name.md")
$out = $t.Replace('{{TITLE}}','Production-Grade RAG').Replace('{{SHORT}}','Ch 03 · Production-Grade RAG').Replace('{{PDFNAME}}',"$name.pdf")
$out = $out.Replace('{{MARKED}}',[IO.File]::ReadAllText("$base\assets\marked.js")).Replace('{{HLJS}}',[IO.File]::ReadAllText("$base\assets\hljs.js"))
$out = $out.Replace('{{MD}}',$md.TrimEnd())
[IO.File]::WriteAllText("$base\PDF\$name.html", $out, $utf8)

# ---- gallery ----
$C = @(
 'Production-Grade RAG &mdash; title',
 'Week 3, Class 1 agenda &mdash; shortcomings, chunking, retrieval, query intelligence, reranking',
 'Recap &mdash; basic RAG: indexing (offline) and querying (online)',
 'Similar is not the same as relevant &mdash; the Zomato refund query',
 'Naive top-4 from a dense retriever &mdash; the right record ranks 3rd',
 'ZH-002 Order marked delivered &mdash; the only relevant record (0.78)',
 'Top-K chunks become the context sent to the LLM',
 'K = 2 &mdash; chunks 1 and 2 go in, the right answer is cut off',
 'Where a basic pipeline breaks &mdash; 7 failures and their fixes',
 'Poor chunking &mdash; 900 characters cut blindly into 3 &times; 300',
 'No metadata filter &mdash; H&amp;M (30 days) vs Zomato; filter tenant_id: zomato',
 '<b>Part 2</b> &mdash; Production-grade RAG architecture',
 'Recall@K = m / K (as written in class; strictly that is Precision@K)',
 'Dense A,B,D,L + Sparse B,A,M,L &rarr; RRF fusion A,B,L,D',
 'Rerank comes next; only top 2 go to the LLM',
 'Rerank result &mdash; D, A, L, B',
 'Top 2 (D, A) &rarr; LLM answer &rarr; citations',
 'What we already have vs what is still to learn',
 'Establish a baseline first &mdash; Q3 &ldquo;I was charged but my order failed&rdquo;',
 'Fixed-size chunking &mdash; 120 characters, 20 overlap',
 'Fixed-size chunks close up &mdash; words and rules cut in half',
 'Structure-aware chunking &mdash; one chunk per section',
 'Hierarchy, chunk metadata, splitter separators, pros and cons',
 'Semantic chunking &mdash; source paragraph and sentence distances',
 'Paragraph P &rarr; lines L1&hellip;L5',
 'Compare L1 and L2 first',
 'Distances between neighbours &mdash; 0.12, 0.16, 0.71, 0.14',
 'd = distance',
 'L1&ndash;L3 together, L4&ndash;L5 together',
 'C1 = L1, L2, L3 &middot; C2 = L4, L5',
 'The jump to 0.71 &mdash; boundary between cancellation and coupons',
 'Watch out &mdash; no universal threshold, more compute, harder to debug',
 'Parent L &rarr; children C1, C2, C3',
 'C2 matches &rarr; return the whole parent',
 '<b>Part 3</b> &mdash; Retrieval: finding candidates (PAY-403 query)',
 'Indexed troubleshooting articles &mdash; only ERR-403 documents PAY-403',
 'Dense results &mdash; AUTH-012 0.91, PAY-021 0.86, ERR-008 0.79',
 'PAY-403 carries little semantic signal &mdash; ERR-403 misses the top 3',
 'V1 &mdash; dense vector, 1536 dims, every slot filled',
 'V2 &mdash; sparse vector, mostly zeros',
 'Dense (meaning) vs sparse (words) vectors',
 'Sparse vectors store words, not meaning',
 'BM25 &mdash; tokenize, term stats, inverted index; TF, IDF, length normalisation, k1/b',
 'Query &ldquo;error ZM-401 coupon&rdquo; &mdash; dense vs BM25 lists',
 'Dense vs BM25 lists &mdash; all five results',
 'Raw scores cannot be added &mdash; the RRF formula',
 'New folder 4_production_rag',
 '4_production_rag_1/main.ipynb',
 'Cell 1 &mdash; API key via getpass, default model deepseek-v4.1-flash',
 'Cell 2 &mdash; QdrantClient, OpenAIEmbeddings (dense), FastEmbedSparse Qdrant/bm25 (sparse), ChatOpenRouter',
 '<b>Part 4</b> &mdash; Hybrid search and Reciprocal Rank Fusion',
 'Dense vs BM25 lists &mdash; error ZM-401 coupon',
 'RRF formula &mdash; k = 60',
 'Contextual retrieval &mdash; raw chunk vs context-enriched chunk',
 '&ldquo;will my money come back&rdquo; &mdash; raw (ZH-009 at #3) vs enriched (ZH-009 at #1, 0.83)',
 'Anthropic &mdash; contextual embeddings &minus;35%, + contextual BM25 &minus;49%',
 'Anthropic conclusion &mdash; the benefits stack',
 'Parent-child retrieval &mdash; Payment troubleshooting parent, three children',
 'Child-only (27 words) vs parent-child (84 words) &mdash; what the model sees',
 'Watch out &mdash; langchain-classic security fixes only until Dec 2026',
 'ParentDocumentRetriever in the notebook &mdash; child 300 / parent 1000',
 'Choosing a retrieval mode',
 'Query intelligence &mdash; query rewriting for follow-ups',
 'Original vs rewritten query &mdash; ZH-001 Late delivery jumps to #1 (0.86)',
 'A rewrite must not rewrite away details',
 'Rewrite chain &mdash; SearchQuery schema + with_structured_output',
 'Self-query &mdash; model proposes filters; tenant_id rejected',
 'Query routing &mdash; policy RAG vs order API vs analytics vs action workflow',
 'Query routing in the notebook &mdash; router_chain + ALLOWED_AREAS'
)
$n = $C.Count; $blocks = @()
for ($i = 0; $i -lt $n; $i++) {
  $nn = '{0:D2}' -f ($i + 1)
  $blocks += "<section class=`"shot`"><div class=`"hd`"><span class=`"num`">$nn<small>/ $n</small></span><span class=`"cap`">$($C[$i])</span></div><div class=`"frame`"><img src=`"assets/$name/$nn.png`"></div></section>"
}
$g = @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Screenshots &mdash; Production-Grade RAG</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  @page { size: A4 landscape; margin: 10mm 12mm 12mm;
    @bottom-right { content: "Page " counter(page); font: 600 8pt Inter, sans-serif; color: #7c3aed; }
    @bottom-left { content: "AI Track \00B7  Ch 03 screenshots"; font: 500 8pt Inter, sans-serif; color: #9a9cb8; } }
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
<section class="cover"><div class="k">AI Track &middot; Screenshots</div>
<h1>Chapter 03 &mdash; Production-Grade RAG<br>Shortcomings of Basic RAG, Chunking, Retrieval, Query Intelligence &amp; Reranking</h1>
<p>Coding Shuttle &middot; Week 3, Class 1 &middot; stills from the session, in order &middot; 2026-10-11</p>
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