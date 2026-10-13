$name = "01-rag-fundamentals-embeddings-similarity-search"
$base = "F:\Claude code\AI\My Learning Notes"
$sp = Split-Path $PSCommandPath
$img = "C:\Users\Lemnovo\AppData\Local\Temp\claude\f--Claude-code\53cd790e-7a66-4787-bde2-3d58435bc1cf\images"   # pasted chat images (session-specific; already-copied assets are kept)
$utf8 = New-Object Text.UTF8Encoding $false

# ---- screenshots -> track assets ----
$assets = "$base\Screenshots\assets\$name"
New-Item -ItemType Directory -Force $assets | Out-Null
1..130 | ForEach-Object { if (Test-Path "$img\$_.png") { Copy-Item "$img\$_.png" ("$assets\{0:D2}.png" -f $_) -Force } }

# ---- notes HTML from the AI template ----
$t = [IO.File]::ReadAllText("$base\assets\ai-notes-template.html")
$md = [IO.File]::ReadAllText("$base\$name.md")
$out = $t.Replace('{{TITLE}}','RAG Fundamentals').Replace('{{SHORT}}','Ch 01 · RAG Fundamentals').Replace('{{PDFNAME}}',"$name.pdf")
$out = $out.Replace('{{MARKED}}',[IO.File]::ReadAllText("$base\assets\marked.js")).Replace('{{HLJS}}',[IO.File]::ReadAllText("$base\assets\hljs.js"))
$out = $out.Replace('{{MD}}',$md.TrimEnd())
[IO.File]::WriteAllText("$base\PDF\$name.html", $out, $utf8)

# ---- gallery ----
$C = @(
 'Class agenda &mdash; OpenRouter, RAG, Embedding, Similarity, Qdrant, Search Strategies',
 'OpenRouter account &mdash; Workspaces (Default Workspace, $0 spend, 1 key)',
 'Models page filtered to <b>Free</b> &mdash; tabs: Text, Image, Speech, Embeddings, Rerank&hellip;',
 'Compare &mdash; Claude Haiku 5.5 vs GPT-6 Astra: context, modalities, input/output price',
 'Compare &mdash; cache-write pricing, latency (0.98 s vs 6.11 s), throughput (177 vs 32 tok/s)',
 'Compare &mdash; features (tool use, caching, no prompt training) and benchmarks',
 'Instructor creating an API key &mdash; name, 7-day expiry, $50 credit limit',
 'Creating my key <code>open-router-key</code> &mdash; 1-year expiry, $50 credit limit',
 'New key shown <b>once only</b> &mdash; copy it now',
 'API Keys list &mdash; open-router-key ($50) + Default key ($100)',
 '<code>uv init</code> &mdash; generated pyproject.toml, src/ai_engg_rag/',
 '<code>uv add openai</code> &mdash; creating .venv, resolving packages',
 'After <code>uv add openai</code> &mdash; 15 packages, <code>openai&gt;=3.24.0</code> in dependencies',
 '<code>.env</code> created in the project root (instructor&rsquo;s key on screen)',
 'New empty <code>main.py</code>',
 '<code>uv add python-dotenv</code>',
 'pyproject.toml &mdash; openai + python-dotenv dependencies',
 'Imports &mdash; asyncio, os, load_dotenv, AsyncOpenAI',
 '<code>load_dotenv()</code> &mdash; load .env into environment variables',
 '<code>ChatService.__init__</code> &mdash; AsyncOpenAI client with OpenRouter base_url',
 '<code>ask()</code> &mdash; chat.completions.create with model <code>openrouter/free</code>',
 'Picking a model &mdash; Models &rarr; Text &rarr; Free',
 'Sorted by Most Popular &mdash; NVIDIA Nemotron 3 Ultra (free), Poolside Laguna',
 'Model switched to <code>nvidia/nemotron-3-ultra-550b-a55b:free</code>',
 '<code>main()</code> &mdash; create ChatService instance',
 '<code>main()</code> &mdash; input query, await ask(), print answer',
 '<code>if __name__ == "__main__": asyncio.run(main())</code>',
 '<code>uv run src/ai_engg_rag/main.py</code> &mdash; Query prompt',
 'First run fails &mdash; traceback for &ldquo;How was the solar system formed?&rdquo;',
 'Claude&rsquo;s fix &mdash; <code>response.choices</code> was None; guard added to show the real API error',
 'Re-run &mdash; Query: What is RAG (slow free model)',
 'Answer from the free model &mdash; what RAG is and its pipeline',
 'Switched to <code>deepseek/deepseek-v4.1-flash</code> &mdash; fast answer on RAG',
 'Streaming vs non-streaming response &mdash; comparison table',
 'New <code>call_llm/</code> folder &mdash; request_response.py + streaming.py',
 'Streaming code &mdash; <code>stream=True</code>',
 '<code>stream_options={"include_usage": True}</code> &mdash; usage arrives in the final chunk',
 '<code>chunk.choices[0].delta</code> is a ChoiceDelta &mdash; only the new text',
 'Streaming <code>main()</code> &mdash; print content as it arrives, then usage',
 'Streaming error &mdash; <code>Upstream error from Nvidia: Service temporarily overloaded</code>',
 'Fix &mdash; switch the streaming model to DeepSeek V4.1 Flash',
 'Streaming output &mdash; &ldquo;How does the LLM work?&rdquo; arriving piece by piece',
 'Usage &mdash; 37 prompt + 2,059 completion = 2,096 total tokens',
 'OpenRouter Logs &mdash; provider, tokens, cost, speed for each call',
 'RAG whiteboard 1 &mdash; query &ldquo;How many leaves do I get?&rdquo; + relevant company data &rarr; LLM',
 'RAG whiteboard 2 &mdash; context (relevant data) + query &rarr; LLM &rarr; Answer',
 'RAG whiteboard 3 &mdash; Retrieval Augmented Generation',
 '<b>Part 2</b> &mdash; What is RAG: Question &rarr; Retriever &rarr; Relevant context &rarr; LLM &rarr; Answer',
 'The big picture &mdash; Indexing row (parse, chunk, embed, Qdrant) + Querying row (similarity search)',
 'Parsing in layman&rsquo;s terms &mdash; the recipe analogy',
 'Parse &mdash; Document (PDF) &rarr; text-format data (100 pages)',
 'Chunking in layman&rsquo;s terms &mdash; the credit-card-number analogy',
 'Same data, 4 chunks &mdash; easier to read and remember',
 'Chunking &mdash; 100 pages of text &rarr; 100 chunks',
 'Chunking strategies &mdash; fixed-size, structural, recursive, semantic',
 'Why RAG is needed &mdash; private, changing, customer-specific data; &ldquo;watch out&rdquo; box',
 'RAG vs LLM-only vs fine-tuning &mdash; three flows',
 'RAG vs fine-tuning table &mdash; best for, updating data, quality depends on',
 'Basic RAG architecture &mdash; indexing (offline) and querying (online) around Qdrant',
 'Turning text into numbers &mdash; text &rarr; embedding model &rarr; vector',
 '1536 numbers &mdash; one embedding vector',
 'Vectors in AI &mdash; the fruit analogy [sweetness, sourness, size]',
 'OpenRouter Models &mdash; Embeddings tab (37 models)',
 'Embedding models &mdash; LFM2.5-Embedding-350M (free, 1024-d), voyage-code-4, voyage-multimodal-3.5',
 'Meaning space in 2D &mdash; programming cluster vs places cluster',
 'What is a dimension?',
 'One, two and three numbers &mdash; ruler, map, drone',
 'Food in 2D &mdash; spicy (x) vs sweet (y); query &ldquo;something sweet&rdquo;',
 'Gulab Jamun [0.05, 0.95] vs Butter Chicken [0.60, 0.20]',
 'Add crunchiness &rarr; 3-dimensional vector',
 'Real embeddings &mdash; far more numbers; axes are learned, not named',
 'Steps 1&ndash;3 &mdash; tokenize, token IDs, embedding-matrix lookup',
 'Butter chicken is spicy &mdash; tokenize &rarr; IDs &rarr; look up &rarr; transformer &rarr; pool &rarr; normalise',
 'Steps 4&ndash;5 &mdash; transformer attention (bank) and pooling',
 'Does more dimensions mean better RAG? &mdash; 256 vs 3072 trade-off',
 'Embeddings in code &mdash; client.embeddings.create(text-embedding-3-small)',
 'Recap &mdash; leave-policy RAG whiteboard (where embeddings fit)',
 'Embedding dimensions and compatibility &mdash; 1536 match vs 768 mismatch error',
 '<b>Part 3</b> &mdash; Measuring similarity: cosine, Euclidean/L2, dot product, Manhattan/L1',
 'Euclidean (straight line) vs Manhattan (city blocks)',
 'Cosine similarity &mdash; A&middot;B / (||A|| ||B||); small angle = high similarity',
 'scikit-learn cosine_similarity + euclidean_distances; &ldquo;read the direction&rdquo; warning',
 'Dot product / inner product &mdash; same ranking as cosine for normalised vectors',
 'Reference lab &mdash; lab1_compare.py (cosine + L2 over 4 docs)',
 'New folder <code>learn_rag_basics/</code>',
 'Notebook <code>1_rag_basics.ipynb</code> created',
 'First cell &mdash; <code>from openai import OpenAI</code>',
 'Imports &mdash; os, load_dotenv, OpenAI',
 '<code>uv add scikit-learn</code> &mdash; numpy, scipy, scikit-learn',
 'Import cosine_similarity, euclidean_distances',
 'OpenAI client on OpenRouter + <code>nvidia/nemotron-3-embed-1b:free</code>',
 'Cell 1 run &mdash; prints the embedding model',
 'Recap whiteboard &mdash; the leave-policy RAG flow (company PDF)',
 'Knowledge base &mdash; 20 documents',
 'Metadata per document &mdash; topic + level',
 '<code>embed_documents()</code> &mdash; list[str] &rarr; list[list[float]]',
 '20 documents loaded &mdash; first text printed',
 'Call <code>embed_documents(texts)</code>',
 'Result &mdash; 20 embeddings, 2048 dimensions each, first 5 values',
 'Printing the full 2048-value vector',
 'Embed the query &mdash; &ldquo;Which programming language is commonly used for AI applications?&rdquo;',
 'Cosine + L2 for the query against all docs',
 'Printing a Cos / L2 / Document table',
 'Scores for all 20 docs',
 'Doc 11 &mdash; negative cosine (&minus;0.005), the least related',
 'Doc 14 (Python) &mdash; best match: cos 0.614, L2 0.878',
 '<code>retrieve()</code> &mdash; sort by score, take top_k',
 'Top-K (k=4) results &mdash; 0.614 Python, then weak 0.199 / 0.152 / 0.137',
 '<b>Part 4</b> &mdash; Decision guide: which distance metric?',
 'Real-world cheat sheet &mdash; cosine, dot, Euclidean, Manhattan scenarios',
 'Why a vector database &mdash; brute force over 10,000,000 vectors',
 'Qdrant local in-memory mode + deployment path',
 'Qdrant docs &mdash; docker pull / docker run, ports 6333 + 6334, Windows volume note',
 '<code>uv add qdrant</code> (wrong package name)',
 '<code>uv add qdrant-client</code> &mdash; 12 packages, qdrant-client 1.19.1',
 'Notebook &mdash; <code>from qdrant_client import QdrantClient, models</code>',
 '<code>QdrantClient(":memory:")</code>',
 'Collection name + delete-if-exists (Docker URL commented out)',
 '<code>create_collection</code> &mdash; size 2048, COSINE',
 'Distance options &mdash; COSINE, DOT, EUCLID, MANHATTAN',
 'Build PointStructs (id, vector, payload) + upsert',
 'Docker Desktop &mdash; run qdrant as <code>qdrant-test</code>, ports 6333/6334',
 'Container running &mdash; v1.19.1, dashboard URL, storage warning',
 'Dashboard &mdash; Collections: none yet',
 'Dashboard &mdash; rag_fundamentals, Point 1 payload, vector length 2048',
 'Inserted 20 points &mdash; <code>query_points</code> cell',
 'Query results &mdash; id=14 score 0.614 on top',
 'Recall vs precision note',
 'Approximate nearest neighbour &mdash; exact (15 compares) vs ANN (6 candidates)',
 'HNSW &mdash; Navigable, Small World, Hierarchical'
)
$n = $C.Count; $blocks = @()
for ($i = 0; $i -lt $n; $i++) {
  $nn = '{0:D2}' -f ($i + 1)
  $blocks += "<section class=`"shot`"><div class=`"hd`"><span class=`"num`">$nn<small>/ $n</small></span><span class=`"cap`">$($C[$i])</span></div><div class=`"frame`"><img src=`"assets/$name/$nn.png`"></div></section>"
}
$g = @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Screenshots &mdash; RAG Fundamentals</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  @page { size: A4 landscape; margin: 10mm 12mm 12mm;
    @bottom-right { content: "Page " counter(page); font: 600 8pt Inter, sans-serif; color: #7c3aed; }
    @bottom-left { content: "AI Track \00B7  Ch 01 screenshots"; font: 500 8pt Inter, sans-serif; color: #9a9cb8; } }
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
<h1>Chapter 01 &mdash; RAG Fundamentals<br>LLMs, RAG Pipeline, Embeddings, Similarity &amp; Qdrant</h1>
<p>Coding Shuttle &middot; Week 1, Class 1 &middot; stills from the session, in order &middot; 2026-10-09</p>
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
