$name = "02-rag-with-langchain"
$base = "F:\Claude code\AI\My Learning Notes"
$sp = Split-Path $PSCommandPath
$img = "C:\Users\Lemnovo\AppData\Local\Temp\claude\f--Claude-code\53cd790e-7a66-4787-bde2-3d58435bc1cf\images"   # pasted chat images (session-specific; already-copied assets are kept)
$utf8 = New-Object Text.UTF8Encoding $false

# ---- screenshots -> track assets ----
$assets = "$base\Screenshots\assets\$name"
New-Item -ItemType Directory -Force $assets | Out-Null
131..215 | ForEach-Object { if (Test-Path "$img\$_.png") { Copy-Item "$img\$_.png" ("$assets\{0:D2}.png" -f ($_ - 130)) -Force } }

# ---- notes HTML from the AI template ----
$t = [IO.File]::ReadAllText("$base\assets\ai-notes-template.html")
$md = [IO.File]::ReadAllText("$base\$name.md")
$out = $t.Replace('{{TITLE}}','RAG with LangChain').Replace('{{SHORT}}','Ch 02 · RAG with LangChain').Replace('{{PDFNAME}}',"$name.pdf")
$out = $out.Replace('{{MARKED}}',[IO.File]::ReadAllText("$base\assets\marked.js")).Replace('{{HLJS}}',[IO.File]::ReadAllText("$base\assets\hljs.js"))
$out = $out.Replace('{{MD}}',$md.TrimEnd())
[IO.File]::WriteAllText("$base\PDF\$name.html", $out, $utf8)

# ---- gallery ----
$C = @(
 'Week 2, Class 2 agenda &mdash; quantization, filtering, RAG with LangChain',
 'Quantization &mdash; float32 6.1 GB vs int8 1.5 GB vs binary 0.19 GB',
 'Scalar quantization in code &mdash; ScalarType.INT8, always_ram=True',
 'Benefits (memory, storage, speed) vs cost (approximation)',
 'Five LangChain interfaces + the providers underneath',
 'Recap &mdash; the hand-written retrieve() from Chapter 01',
 'Top row &mdash; loader, splitter, embeddings, vector store, chat model',
 'Providers &mdash; green in use, pink drop-in replacements',
 'What is LangChain? &mdash; a standard interface for every part',
 'What it gives you vs what it is not',
 'The components map &mdash; prepare once, answer every time',
 'How the packages fit together &mdash; langchain-core hub and spokes',
 'Install the packages &mdash; pip install -U langchain ...',
 'New folder <code>langchain_rag</code>',
 'Renamed to <code>3_langchain_rag</code>',
 'Folders numbered 1_call_llm, 2_learn_rag_basics, 3_langchain_rag + main.ipynb',
 '<code>uv add langchain ...</code> &mdash; langchain 1.4.3, langgraph, langsmith',
 'pyproject.toml &mdash; new LangChain dependencies',
 'From files to Documents &mdash; page_content + metadata',
 'Document object in code',
 'Document loaders &mdash; many sources &rarr; .load() &rarr; list of Documents',
 'knowledge/ folder &mdash; catalog, faq, policies, scans, wiki',
 'support_faq.csv &mdash; question, answer, product, category',
 'support_faq.csv &mdash; product and category columns',
 'policies/employee_handbook.pdf &mdash; 8 pages',
 'scans/vendor_contract.pdf &mdash; scanned Master Services Agreement',
 'wiki/holiday_calendar.html',
 'wiki/onboarding.md &mdash; Markdown preview',
 'Notebook &mdash; load_dotenv + assert keys exist',
 '&ldquo;API keys loaded&rdquo;',
 'Document cell in the notebook',
 'Document output &mdash; text + metadata dict',
 'onboarding.md raw Markdown (headings)',
 'TextLoader vs UnstructuredMarkdownLoader',
 'TextLoader output &mdash; 1 Document, source metadata, DeprecationWarning',
 '<code>uv add unstructured</code> &mdash; spacy, lxml, llvmlite',
 '<code>ModuleNotFoundError: No module named &#39;unstructured&#39;</code>',
 'Still failing at <code>import markdown</code>',
 '<code>uv add markdown</code>',
 'UnstructuredMarkdownLoader running (9.4 s)',
 'PyPDFLoader &mdash; 8 pages loaded, page metadata',
 'PDF loader comparison &mdash; PyPDF, PyMuPDF, PDFPlumber',
 'Scanned PDFs need OCR &mdash; poppler, Tesseract, partitioning',
 '<code>uv add &quot;unstructured[pdf]&quot;</code> &mdash; zsh needs quotes; torch, onnx',
 'UnstructuredPDFLoader &mdash; mode=elements, strategy=ocr_only',
 'Watch out &mdash; OCR mistakes; managed parsers (LlamaParse, Azure, Textract)',
 'OCR result &mdash; 56 elements, Title | MASTER SERVICES AGREEMENT, 1m 54s',
 'From Documents to chunks &mdash; size 900, overlap 120',
 'RecursiveCharacterTextSplitter code',
 'Overlap &mdash; size 5, overlap 1 over A&ndash;L',
 'Tokens &mdash; one sentence, three encodings',
 'platform.openai.com/tokenizer &mdash; 7 tokens, 34 characters',
 '<b>Part 2</b> &mdash; Chunking: PyMuPDFLoader on the handbook',
 'Handbook: 8 pages, 11,016 characters',
 'RecursiveCharacterTextSplitter &mdash; 900 / 120 / add_start_index',
 'Split 8 pages into 16 chunks',
 'PII redaction &mdash; hide personal data before the model or DB',
 'Embedding providers compared &mdash; one interface',
 'OpenAIEmbeddings via OpenRouter &mdash; embed_documents / embed_query',
 '<code>AuthenticationError 401 &ndash; User not found</code>',
 'After kernel restart &mdash; ran in 3.6 s',
 'QdrantVectorStore.from_documents &mdash; ids, :memory:, helpdesk_kb',
 'Full control &mdash; create the collection yourself, then wrap it',
 'chunk_id() &mdash; sha1 + uuid5; custom metadata incl. tenant_id',
 'Load &rarr; tag &rarr; chunk &rarr; ids &rarr; add_documents',
 '8 pages &middot; 16 chunks &middot; 16 unique IDs &middot; 16 points',
 'Qdrant dashboard &mdash; helpdesk_kb 16 points, 1536, Cosine',
 'Point payload &mdash; page_content + metadata (tenant_id, start_index)',
 'similarity_search(question, k=3)',
 'Results with filename + page &mdash; &ldquo;vacation days&rdquo; matched annual leave',
 'as_retriever(k=4) &mdash; client dinner question',
 'Retrieved 4 docs &mdash; Benefits page (expense policy not indexed)',
 'ChatOpenRouter &mdash; deepseek-v4.1-flash, temperature=0',
 'Temperature explained &mdash; 0 = fact-checking robot',
 'LLM answer &mdash; &ldquo;Explain RAG in one sentence&rdquo;',
 'ChatPromptTemplate &mdash; system rules + {context} + {question}',
 'format_docs() &mdash; numbered chunks with filename',
 'Explicit pipeline &mdash; retrieve, format, prompt, generate',
 'Output &mdash; 4 docs, 3,084 chars, 2 messages, grounded WFH answer',
 'The same pipeline as an LCEL chain &mdash; diagram',
 'LCEL code &mdash; dict | prompt | llm | StrOutputParser',
 'LCEL in the notebook',
 'LCEL answer &mdash; 2 days remote per week (despite the &ldquo;homw&rdquo; typo)',
 'The explicit RAG pipeline &mdash; diagram + cite() helper note',
 'Debugging a RAG pipeline &mdash; inspect every stage'
)
$n = $C.Count; $blocks = @()
for ($i = 0; $i -lt $n; $i++) {
  $nn = '{0:D2}' -f ($i + 1)
  $blocks += "<section class=`"shot`"><div class=`"hd`"><span class=`"num`">$nn<small>/ $n</small></span><span class=`"cap`">$($C[$i])</span></div><div class=`"frame`"><img src=`"assets/$name/$nn.png`"></div></section>"
}
$g = @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Screenshots &mdash; RAG with LangChain</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  @page { size: A4 landscape; margin: 10mm 12mm 12mm;
    @bottom-right { content: "Page " counter(page); font: 600 8pt Inter, sans-serif; color: #7c3aed; }
    @bottom-left { content: "AI Track \00B7  Ch 02 screenshots"; font: 500 8pt Inter, sans-serif; color: #9a9cb8; } }
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
<h1>Chapter 02 &mdash; RAG with LangChain<br>Quantization, Loaders, Chunking, Embeddings, Qdrant &amp; LCEL</h1>
<p>Coding Shuttle &middot; Week 2, Class 2 &middot; stills from the session, in order &middot; 2026-10-10</p>
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