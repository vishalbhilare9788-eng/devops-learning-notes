# AI Master Notes — Interview & Production Reference

> **Living document**, built the same way as the Kubernetes, ArgoCD and Terraform master notes. As you
> dictate what a session/video covered (or share screenshots), the topic gets its own section below,
> written as theory + real-world/production example + command/code reference + hands-on practice tasks.

---

## Table of Contents
1. [RAG Fundamentals: Calling LLMs & How RAG Works](#1-rag-fundamentals-calling-llms--how-rag-works) *(Ch 01 Part 1)*
2. [RAG Pipeline & Embeddings](#2-rag-pipeline--embeddings) *(Ch 01 Part 2)*
3. [Similarity Metrics & Retrieval by Hand](#3-similarity-metrics--retrieval-by-hand) *(Ch 01 Part 3)*
4. [Vector Databases, Qdrant & ANN/HNSW](#4-vector-databases-qdrant--annhnsw) *(Ch 01 Part 4)*
5. [LangChain Basics: Quantization, Documents & Loaders](#5-langchain-basics-quantization-documents--loaders) *(Ch 02 Part 1)*
6. [LangChain RAG Pipeline: Embeddings, Qdrant, Retriever, LCEL](#6-langchain-rag-pipeline-embeddings-qdrant-retriever-lcel) *(Ch 02 Part 2)*
7. [Production RAG: Why Basic RAG Breaks](#7-production-rag-why-basic-rag-breaks) *(Ch 03 Part 1)*
8. [Production RAG Architecture & Chunking Strategies](#8-production-rag-architecture--chunking-strategies) *(Ch 03 Part 2)*
9. [Dense vs Sparse Retrieval & BM25](#9-dense-vs-sparse-retrieval--bm25) *(Ch 03 Part 3)*
10. [Contextual Retrieval, Parent-Child & Query Intelligence](#10-contextual-retrieval-parent-child--query-intelligence) *(Ch 03 Part 4)*
11. [Reranking, RAG Security & Evaluation](#11-reranking-rag-security--evaluation) *(Ch 04)*

---

## 1. RAG Fundamentals: Calling LLMs & How RAG Works

### 📘 Theory
- **LLM limits:** trained on past, public data, so it has a **knowledge cut-off**, **no private/company data**, and **hallucinates** when it doesn't know.
- **Two ways to add your knowledge:**
  - **Fine-tuning** changes model weights. Good for behaviour/style, but costly and goes stale.
  - **RAG** leaves the model as it is and injects relevant data into the prompt per request. Good for knowledge that changes.
- **RAG = Retrieval-Augmented Generation:**
  - **Retrieval:** fetch the relevant pieces of your data for this query.
  - **Augmented:** add them to the query as **context**.
  - **Generation:** the LLM answers from that augmented input.
  The model never changes. Only **its input** does.
- **OpenRouter:** one OpenAI-compatible API and key in front of hundreds of models and providers. You switch models via the `model` string. It gives you per-key credit limits, Compare (price/latency/throughput/benchmarks) and per-call Logs.
- **Streaming vs non-streaming:** streaming (`stream=True`) yields tokens as they're generated, so the first word appears fast. Non-streaming returns everything at the end.
- **`AsyncOpenAI`:** non-blocking client, so one service can handle many concurrent requests.

### 🏢 Real-world example
An internal **HR/IT help-desk bot**. An employee asks *"How many leaves do I get?"*. The system retrieves the leave-policy section from the company's Confluence/policies and sends it to the LLM as context together with the question. The LLM answers from *our* policy instead of guessing. When the policy changes, you update the documents, not the model.

**Model choice is a cost/latency/quality trade-off.** Class example: Claude Haiku 5.5 costs $0.10/$0.50 per M tokens with 0.98 s p50 latency, against GPT-6 Astra at $10/$50 and 6.11 s. Haiku is ~100× cheaper and ~6× faster for a slightly lower intelligence score. That's usually the right pick for a high-volume bot.

### 🛠️ Command & code reference
```bash
uv init                       # new project (pyproject.toml, src/<pkg>/)
uv add openai python-dotenv   # SDK + .env loader
uv run src/ai_engg_rag/main.py
```
```bash
# .env (project root, git-ignored)
OPENROUTER_API_KEY=sk-or-v1-...
```
```python
from openai import AsyncOpenAI
client = AsyncOpenAI(api_key=os.environ["OPENROUTER_API_KEY"],
                     base_url="https://openrouter.ai/api/v1")

# non-streaming
r = await client.chat.completions.create(model="deepseek/deepseek-v4.1-flash",
        messages=[{"role": "user", "content": q}])
if not r.choices: raise ValueError(f"Empty choices: {r}")   # surface API errors
answer = r.choices[0].message.content

# streaming + token usage
stream = await client.chat.completions.create(model=..., messages=..., stream=True,
        stream_options={"include_usage": True})
async for chunk in stream:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
    if chunk.usage:                      # final chunk
        print(chunk.usage.prompt_tokens, chunk.usage.completion_tokens, chunk.usage.total_tokens)

# RAG = augmented messages
messages = [{"role": "system", "content": "Answer only from the context. If it isn't there, say you don't know."},
            {"role": "user", "content": f"Context:\n{chunks}\n\nQuestion: {q}"}]
```

| Model ID example | Note |
|---|---|
| `openrouter/free` | OpenRouter picks any free model at runtime |
| `nvidia/nemotron-3-ultra-550b-a55b:free` | Free but slow and sometimes "temporarily overloaded" |
| `deepseek/deepseek-v4.1-flash` | Paid, fast. ~$0.0009 for a 2K-token answer |

**Troubleshooting**

| Symptom | Cause | Fix |
|---|---|---|
| `TypeError: 'NoneType' object is not subscriptable` on `response.choices[0]` | API returned an error (bad model ID / upstream failure) | Guard `if not response.choices`, print the full response, fix the model |
| `openai.APIError: Upstream error from Nvidia: Service temporarily overloaded` | Free provider overloaded | Retry/backoff or switch model. Check the model supports streaming |
| `KeyError: 'OPENROUTER_API_KEY'` | `.env` missing, not in root, or the line has no `NAME=` | `OPENROUTER_API_KEY=...` in the project root, then `load_dotenv()` |

### 🧪 Practice tasks
1. Create an OpenRouter key with a **$5 credit limit and 30-day expiry**. Confirm it appears in API Keys.
2. Build `call_llm_request_response.py` and ask the same question with `openrouter/free` and with DeepSeek. Compare speed and answer quality.
3. Build the streaming version. Print the token usage and match it to the row in OpenRouter **Logs** (tokens + cost).
4. Use **Compare** to pick the cheapest model with ≥128K context and tool use, and justify the choice in one line.
5. Hand-made RAG: paste a fake "leave policy" paragraph as context into `messages`, ask *"How many leaves do I get?"*, then ask again without the context and compare the answers.

---

## 2. RAG Pipeline & Embeddings

### 📘 Theory
- **Two jobs:** the retriever *finds*, the LLM *generates*. When an answer is wrong, first check **did we retrieve the right chunk?**
- **Two pipelines joined by a vector DB:**
  - **Indexing** (offline, per document): parse → chunk → embed → store vector + payload (Qdrant).
  - **Querying** (online, per question): embed query → similarity search → top-K chunks → prompt + context → LLM.
- **Why not keyword search?** The exact phrase isn't in the doc, the doc uses synonyms ("PTO" vs "leaves"), or it's a scanned image. You need **semantic** (meaning) match.
- **Why not send everything?** Cost per token, latency, and the relevant fact gets buried, which leads to hallucination. Send only the best 2–3 chunks.
- **Parsing** = raw document → clean text. **Chunking** = text → small pieces (fixed-size / structural / recursive / semantic).
- **RAG vs fine-tuning:**

  | | RAG | Fine-tuning |
  |---|---|---|
  | Best for | External, current knowledge | Behaviour and task adaptation |
  | Update | Re-index | Retrain |
  | Quality depends on | Retrieval | Training data |

  RAG improves grounding, but bad retrieval still gives a confident wrong answer.
- **Embedding** = fixed-length vector representing meaning. Close vectors mean similar meaning (Java/Python/Spring Boot vs Delhi/Paris/Tokyo; river bank vs money bank).
- **Dimension** = number of values per vector (384/768/1536/3072). The axes are **learned, not named**.
- **How a vector is built:** tokenize (`[CLS] … [SEP]`) → token IDs → embedding-matrix lookup → transformer attention (context) → pool (average) → normalise to length 1 (`|v| = √(Σvᵢ²)`).
- **More dims ≠ automatically better.** Storage is 4 bytes × dims per chunk:

  | Dims | Per vector | Per 1M chunks |
  |---|---|---|
  | 256 | 1 KB | ~1 GB |
  | 1536 | 6 KB | ~6 GB |
  | 3072 | 12 KB | ~12 GB |

  Chunking, model quality and filters matter more. **Measure recall** (found relevant ÷ all relevant) first.
- **Compatibility:** the collection size must equal the model's dims, or inserts fail. Vectors only make sense to the model that made them. **Change the model → re-embed and re-index everything.**

### 🏢 Real-world example
An HR policy bot over 2,000 Confluence pages. Indexing runs nightly (or on page-update webhooks), so only changed pages are re-parsed, re-chunked and re-embedded. At query time, "How many leaves do I get?" is embedded and matched to the "Annual paid time off" chunk, even though the word "leaves" isn't in it. Only the top 3 chunks go to the LLM. When the team later switches embedding model to cut cost (1536 → 768 dims), they build a **new collection**, re-index fully, and switch traffic over. They never mix vectors in the old collection.

### 🛠️ Code reference
```python
from openai import OpenAI
client = OpenAI()   # or OpenAI(api_key=..., base_url="https://openrouter.ai/api/v1") with an embeddings model ID
resp = client.embeddings.create(model="text-embedding-3-small",
                                input=["Java is a programming language", "Python is used for machine learning"])
vectors = [d.embedding for d in resp.data]
dim = len(vectors[0])          # 1536. Use this for the Qdrant collection size, never hard-code it
```

### 🧪 Practice tasks
1. Draw the indexing and querying pipelines from memory, and mark which steps run offline and which online.
2. Embed 6 sentences (3 programming, 3 cities), print `len(vector)`, and confirm that every vector has the same length regardless of sentence length.
3. Compute the storage for 500K chunks at 384, 1536 and 3072 dims.
4. Embed "I deposited cash at the bank" and "We sat on the river bank" and keep the vectors. Next part: compare them with cosine similarity.
5. Write down one question for your company where RAG fits and one where fine-tuning fits, and justify each.

---

## 3. Similarity Metrics & Retrieval by Hand

### 📘 Theory
Retrieval means finding the chunk vectors **closest** to the query vector. The **metric** defines "close":

| Metric | Formula / intuition | Better = |
|---|---|---|
| **Cosine** | `A·B / (‖A‖‖B‖)`: angle only. Range −1..1, text mostly 0..1 | **Higher** |
| **Euclidean / L2** | `√Σ(aᵢ−bᵢ)²`: straight line | **Lower** |
| **Dot product** | `Σ aᵢbᵢ`: alignment + magnitude | **Higher** |
| **Manhattan / L1** | `Σ|aᵢ−bᵢ|`: city blocks | **Lower** |

- **Normalised vectors** (most embedding models): cosine, dot product and L2 all give the **same ranking** (`L2² = 2 − 2·cos`). Dot product is the cheapest.
- **#1 bug:** sorting the wrong way. Cosine/dot sort **descending**, L2/L1 sort **ascending**.
- **Top-K always returns K results.** Add a **min-score threshold** (tuned per model, e.g. 0.5 for cosine) so weak matches don't reach the LLM.
- **Embed once and store.** Never re-embed the same docs on every query.

### 🏢 Real-world example
Lab with 20 tech one-liners, using `nvidia/nemotron-3-embed-1b:free` (2048 dims). Query *"Which programming language is commonly used for AI applications?"* → **Python doc: cos 0.614 / L2 0.878** (best on both). Next best was only 0.199 (async programming). The least related doc scored cos −0.005 / L2 1.418. With top_k=4 and no threshold, 3 irrelevant docs would have gone to the LLM. A 0.5 threshold keeps only the Python doc.

### 🛠️ Code reference
```python
from sklearn.metrics.pairwise import cosine_similarity, euclidean_distances   # uv add scikit-learn

def embed_documents(texts: list[str]) -> list[list[float]]:
    resp = client.embeddings.create(model=EMBEDDING_MODEL, input=texts)
    return [d.embedding for d in resp.data]

doc_embeddings = embed_documents([d["text"] for d in documents])   # index once
query_embedding = embed_documents([query])                          # same model!

def retrieve(query_emb, doc_embs, docs, top_k=4, min_score=0.5):
    scores = cosine_similarity(query_emb, doc_embs)[0]
    scored = sorted(zip(docs, scores), key=lambda x: x[1], reverse=True)   # cosine → highest first
    return [{"document": d, "score": float(s)} for d, s in scored[:top_k] if s >= min_score]
```

### 🧪 Practice tasks
1. Re-run the lab and print cosine, L2 **and** dot product (`numpy.dot`) for every doc. Confirm all three rank the docs the same.
2. Check that the vectors are normalised: `numpy.linalg.norm(doc_embeddings[0])` should be ≈ 1.
3. Ask 3 new questions (e.g. "How do I cache data?", "What orchestrates containers?") and note the top score and the gap to #2.
4. Find a threshold that keeps the right doc for all 3 questions and drops the noise.
5. Ask something not in the KB ("What's the capital of France?"). Does anything pass the threshold? Make `retrieve` return "I don't know" when the list is empty.

---

## 4. Vector Databases, Qdrant & ANN/HNSW

### 📘 Theory
- **Choosing a metric:**
  - Normalised vectors → **dot product** (fastest, same ranking as cosine).
  - Magnitude matters (popularity) → **dot product**.
  - Text/RAG → **cosine**.
  - Outliers or noisy, high-dimensional data → **Manhattan**.
  - Coordinates/pixels → **Euclidean**.
- **Why a vector DB:** brute force over 10M vectors is too slow. A vector DB gives storage + an **ANN index** + metadata **filtering** + persistence/snapshots/**scaling**. Options: Qdrant (OSS, Rust), pgvector, Pinecone, Weaviate, Milvus, Chroma.
- **Qdrant model:**
  - **Collection** ≈ table: fixed `size` + `distance`.
  - **Point** ≈ row: `id` + `vector` + `payload` JSON.
  - **Upsert** = insert or update by id.
- **Recall** = relevant found ÷ all relevant. **Precision** = relevant ÷ returned. A bigger K means higher recall and lower precision.
- **Exact vs ANN:**
  - Exact compares the query with every vector: 100% recall, slow.
  - ANN uses an index to check only promising candidates: fast, and occasionally misses a neighbour.
- **HNSW** (Qdrant's index) = Hierarchical Navigable Small World. It's a layered graph: start at the sparse top layer, then hop greedily closer layer by layer (highway → main road → street). **IVF** = cluster-based alternative.

### 🏢 Real-world example
For the HR-policy bot, run Qdrant in Docker or Kubernetes with a **persistent volume** on `/qdrant/storage` (the class container warned that storage would be lost on re-creation).
- One collection per embedding model, e.g. `hr_policies_v1` (2048-d, COSINE).
- Each chunk goes in as a point with payload `{text, source_url, department, updated_at}`.
- At query time, `query_points(limit=5, score_threshold=…, filter=department=HR)` returns only HR chunks above the threshold.
- Track the dashboard's **ANN Recall** after index changes.

### 🛠️ Command & code reference
```bash
uv add qdrant-client
docker run -d --name qdrant -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
# REST + dashboard: http://localhost:6333/dashboard   gRPC: 6334
```
```python
from qdrant_client import QdrantClient, models
qdrant = QdrantClient(":memory:")                 # or url="http://localhost:6333"
if qdrant.collection_exists(C): qdrant.delete_collection(C)
qdrant.create_collection(C, vectors_config=models.VectorParams(
    size=len(doc_embeddings[0]), distance=models.Distance.COSINE))   # COSINE|DOT|EUCLID|MANHATTAN
qdrant.upsert(C, points=[models.PointStruct(id=d["id"], vector=v,
    payload={"text": d["text"], "topic": d["topic"], "level": d["level"]})
    for d, v in zip(documents, doc_embeddings)], wait=True)
hits = qdrant.query_points(C, query=query_embedding[0], limit=5, with_payload=True).points
for h in hits: print(h.id, h.score, h.payload["text"])          # id=14 score=0.614 (same as sklearn)
```

### 🧪 Practice tasks
1. Run Qdrant in Docker **with a named volume**, load the 20 docs, restart the container, and confirm the collection survives.
2. Repeat with `Distance.DOT` and `EUCLID` and compare the top-5 order. Explain why it matches (normalised vectors).
3. Add `score_threshold=0.5`, then a payload filter `topic == "ai"`, and see how the results change.
4. Open the dashboard → **ANN Recall** tab for the collection and note what it reports.
5. Write a 5-line explanation of HNSW using the highway → main road → street analogy, as if for an interview.

---

## 5. LangChain Basics: Quantization, Documents & Loaders

### 📘 Theory
- **Quantization** stores vectors at lower precision (1M × 1536 dims):

  | Storage | Size | Bytes per dimension |
  |---|---|---|
  | float32 | 6.1 GB | 4 bytes |
  | int8 | 1.5 GB | 1 byte |
  | binary | 0.19 GB | 1 bit |

  You gain RAM, storage and speed, at the cost of a small accuracy loss (measuring tape with only feet marked). Set it per collection.
- **LangChain** is an open-source framework with **one standard interface per job**: loader → splitter → embeddings → vector store → chat model. Providers underneath are swappable (PyPDF/PyMuPDF/Unstructured · Recursive/Markdown/Token · OpenAI/HuggingFace/Ollama · Qdrant/Chroma/pgvector · OpenRouter/OpenAI/Groq). It's a toolbox, not RAG, not a DB, not a model.
- **Eight components:**
  - Indexing: loader → splitter → embedding model → vector store.
  - Querying: retriever → prompt template → chat model → output parser.
- **Packages:** `langchain-core` is the hub (Document, Runnable, prompts, parsers). The spokes are `-community` (loaders), `-text-splitters`, `-openai`, `-qdrant`, `-openrouter`, `langchain`.
- **Document** = `page_content` + `metadata` (source, page, custom keys). Metadata becomes the Qdrant payload, used for filtering and citations.
- **Loaders** return `list[Document]`:
  - TextLoader: 1 file → 1 Document, keeps the Markdown headings.
  - PyPDFLoader: 1 Document per page.
  - Scanned PDFs need **OCR**, e.g. `UnstructuredPDFLoader(mode="elements", strategy="ocr_only")` with Tesseract + Poppler installed on the OS. It's slow (7 pages took 1m54s) and error-prone.
- **Splitting:** RecursiveCharacterTextSplitter tries paragraphs → lines → spaces. Example settings: size 900, overlap 120. Metadata is copied onto every chunk.
- **Tokens:** sub-word pieces with integer IDs, the unit for billing and context limits. Counts vary by encoding (r50k / cl100k / o200k). Roughly 1 token ≈ 4 characters.

### 🏢 Real-world example
A help-desk bot for a food-delivery company indexes FAQs (CSV), the HR handbook (PDF), scanned vendor contracts, the wiki (HTML/MD) and code. Each source gets the right loader and its metadata (`source`, `page`, `area`), so answers can cite the file and page and be filtered by department. OCR for scanned contracts runs in a **separate indexing container** with Tesseract/Poppler baked in, so the slow, heavy `unstructured[pdf]` stack (torch, onnx) never sits in the chatbot API image. For 10M chunks, int8 quantization cuts the vector RAM from about 60 GB to about 15 GB.

### 🛠️ Command & code reference
```bash
uv add langchain langchain-core langchain-community langchain-openai langchain-openrouter \
       langchain-qdrant langchain-text-splitters qdrant-client python-dotenv pypdf pymupdf
uv add unstructured markdown          # UnstructuredMarkdownLoader
uv add "unstructured[pdf]"            # OCR (quote it in zsh) + OS packages: tesseract, poppler
```
```python
quantization_config=models.ScalarQuantization(scalar=models.ScalarQuantizationConfig(
    type=models.ScalarType.INT8, always_ram=True))

from langchain_core.documents import Document
from langchain_community.document_loaders import TextLoader, PyPDFLoader, UnstructuredPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter

md    = TextLoader("knowledge/wiki/onboarding.md", encoding="utf-8").load()      # 1 Document
pages = PyPDFLoader("knowledge/policies/employee_handbook.pdf").load()           # 8 Documents
scan  = UnstructuredPDFLoader("knowledge/scans/vendor_contract.pdf",
                              mode="elements", strategy="ocr_only").load()       # 56 elements
chunks = RecursiveCharacterTextSplitter(chunk_size=900, chunk_overlap=120,
                                        add_start_index=True).split_documents(pages)
```

| Error | Fix |
|---|---|
| `No module named 'unstructured'` | `uv add unstructured` |
| Fails at `import markdown` | `uv add markdown` |
| `zsh: no matches found: unstructured[pdf]` | Quote it: `uv add "unstructured[pdf]"` |
| OCR returns nothing or errors | Install `tesseract` + `poppler` on the OS |

### 🧪 Practice tasks
1. Work out the RAM for 5M chunks at 1024 dims for float32, int8 and binary.
2. Load `onboarding.md` with TextLoader and with UnstructuredMarkdownLoader, then compare the outputs. Which keeps the headings?
3. Load one PDF with PyPDFLoader and with PyMuPDFLoader, and compare the speed and reading order.
4. Try selecting text in a scanned PDF. Then write the Dockerfile lines needed to run OCR (`apt-get install tesseract-ocr poppler-utils`).
5. Paste a paragraph of your runbook into platform.openai.com/tokenizer and compare the token count with the character count ÷ 4.

---

## 6. LangChain RAG Pipeline: Embeddings, Qdrant, Retriever, LCEL

### 📘 Theory
- **Stable IDs:** `uuid5(NAMESPACE_URL, filename + "|" + sha1(text))`. Deterministic, so a re-index upserts instead of duplicating (idempotent).
- **Compliance before indexing:**
  - PII redaction (mask names, phone numbers, Aadhaar).
  - Skip ID-document scans.
  - Multi-tenancy: `tenant_id` in the payload plus a mandatory filter (`metadata.tenant_id` in LangChain's nested payload).
- **Embeddings interface:** `embed_documents()` / `embed_query()`. Provider choice is a business decision: hosted (OpenAI, Cohere, Google) vs local (HuggingFace, Ollama: private, free).
- **QdrantVectorStore:**
  - `from_documents` (quick: embeds, creates the collection and upserts in one call).
  - Or create the collection yourself, with size from `embed_query("probe")`, and wrap it with `QdrantVectorStore(client=…)`.
  - Two jobs: `add_documents` and `similarity_search`.
- **Retriever** = `vector_store.as_retriever(k=4)`, a Runnable (`.invoke(q) → Documents`). It **always returns k results**, even if the right document was never indexed.
- **Generation:**
  - `ChatOpenRouter(model, temperature=0)` returns an `AIMessage`.
  - `ChatPromptTemplate` holds the system rules + `{context}` and the human `{question}`.
  - `format_docs` numbers the chunks and adds the filename for citations.
- **LCEL:** Runnables joined with `|`:
  ```text
  {context: retriever | format_docs, question: RunnablePassthrough()} | prompt | llm | StrOutputParser()
  ```
  `.invoke/.stream/.batch` come free.
- **Debugging order:** retrieved docs (indexed?) → context length → prompt messages → LLM.
- **Two-step RAG** (fixed retrieve → generate) vs **agentic RAG** (an agent decides when and what to retrieve).

### 🏢 Real-world example
Zomato help desk, built from the handbook only:
- 8 pages → 16 chunks → 16 deterministic IDs → `helpdesk_kb` (1536-d, cosine).
- "How many vacation days?" matched "annual leave" (semantic search). "Work-from-home policy?" retrieved 4 chunks (3,084 characters) and gave a grounded answer (3 days in the office, ₹15,000 setup allowance).
- "Client dinner reimbursement" returned the **Benefits** page because `expense_policy.pdf` was never indexed. That's a coverage bug, not an LLM bug.
- In production, run indexing as a scheduled job over **all** knowledge folders and alert when a source fails to load.

### 🛠️ Code reference
```python
embeddings = OpenAIEmbeddings(model="openai/text-embedding-3-small",
    openai_api_base="https://openrouter.ai/api/v1", api_key=os.environ["OPENROUTER_API_KEY"])
vector_store = QdrantVectorStore.from_documents(documents=chunks, embedding=embeddings, ids=ids,
    url="http://localhost:6333", collection_name="helpdesk_kb")
retriever = vector_store.as_retriever(search_kwargs={"k": 4})
llm = ChatOpenRouter(model="deepseek/deepseek-v4.1-flash", temperature=0)
prompt = ChatPromptTemplate.from_messages([("system", "Answer only from context. If not there, say you don't know.\n\nContext:\n{context}"),
                                           ("human", "{question}")])
rag_chain = ({"context": retriever | format_docs, "question": RunnablePassthrough()}
             | prompt | llm | StrOutputParser())
rag_chain.invoke("How many days of work from home can I have?")
```

| Error | Fix |
|---|---|
| `AuthenticationError 401 'User not found'` | Key not loaded in the kernel: restart the kernel, `load_dotenv()`, check the key |
| Duplicate points after a re-run | Pass deterministic `ids=` |
| Plausible but wrong answer | Check retrieval: was the right file indexed? |

### 🧪 Practice tasks
1. Index `expense_policy.pdf` too, then re-ask "How do I reimburse a client dinner?" and compare.
2. Re-run the indexing cell twice and confirm the point count stays at 16.
3. Add a second tenant (`tenant_id="acme"`) with one fake document. Build a filtered retriever and prove Zomato queries never return Acme chunks.
4. Run the chain at temperature 0 and at 1.0, three times each, and note how the answers vary.
5. Break the prompt on purpose (remove `{context}`) and use the 4-stage debug code to find the problem.

---

## 7. Production RAG: Why Basic RAG Breaks

### 📘 Theory
- **Basic RAG** = indexing (parse → chunk → embed → store) + querying (embed query → vector search → top-K → prompt → LLM). Fine in a demo, breaks at scale.
- **Similar ≠ relevant.** Dense (vector) search ranks by closeness of meaning, not by "does this answer the question". If the right chunk ranks below K, the LLM never sees it.
- **The 7 failure modes and their fixes:**

| Failure | Symptom | Fix |
|---|---|---|
| Similarity mistaken for relevance | Answer about the wrong scenario | Hybrid search (dense + keyword), reranking |
| Missing evidence | Confident made-up promise ("definitely refunded") | Grounded prompt + abstention ("I don't know") |
| Poor chunking | Fact without its condition (timeline without eligibility) | Overlap, structure-aware/semantic chunking, parent-child retrieval |
| No metadata filter | Another tenant's or product's policy | Trusted metadata filters (`tenant_id` from the session) |
| No attribution | Answer nobody can audit | Citations per claim + validation |
| No evaluation | Changes shipped on one good demo | Labelled eval set, run on every change (regression test) |
| No failure handling | Timeout → fabricated answer | Timeouts, fallbacks, fail-closed refusals |

### 🏢 Real-world example
Zomato help desk: *"Order says delivered, never received, paid online. Refund?"* Dense top-4 returned refund status (0.83), restaurant cancellation (0.79), **order marked delivered (0.78, the correct one)** and payment debited/order failed (0.74). With K = 2 the correct record is dropped and the bot answers about the wrong situation. In a multi-tenant bot (H&M 30-day refunds vs Zomato 2-hour refunds), a missing `tenant_id` filter leaks one client's policy to another, which is both a quality bug and a security incident.

### 🛠️ Code reference
```python
# Trusted tenant filter: tenant_id comes from the authenticated session, never from user text
retriever = vector_store.as_retriever(search_kwargs={"k": 4, "filter": {"tenant_id": session.tenant_id}})

# Grounded + abstaining system prompt
SYSTEM = (
    "Answer ONLY from the context. Cite the source id after each claim, e.g. [ZH-002]. "
    "If the context does not contain the answer, say you don't have that information "
    "and suggest contacting support. Never promise refunds that the context does not state."
)
```

### 🧪 Practice tasks
1. Run the Zomato refund query against your KB and log the top-4 with scores. Where does the truly relevant chunk rank?
2. Change K from 2 to 4 and compare the answers. Then think about why "just raise K" isn't the real fix (cost, noise, hallucination).
3. Ask a question the KB can't answer and confirm the bot abstains instead of guessing.
4. Write a 10-query labelled eval set (query → expected chunk ids) and compute how often the expected chunk is in the top-K.
5. Simulate a vector DB timeout and make the pipeline return a fail-closed message.

---

## 8. Production RAG Architecture & Chunking Strategies

### 📘 Theory
- **Router first:** vector search always returns *something*, even for "what is 2 + 2?". A router decides whether RAG should handle the query and which path or docs to use.
- **Production pipeline:** Question → **trusted identity** (auth/RBAC) → **query rewrite** (improves recall) → **access filter** (metadata `must`/`must_not`, tenant/role scope) → **dense** + **sparse/BM25** in parallel → **RRF fusion** (`Σ 1/(60 + rank)`) → **rerank** → **dedup + select top-K** → **LLM answer** → **citations**.
- **Recall@K** = relevant in top K ÷ all relevant; **Precision@K** = relevant in top K ÷ K.
- **Baseline first:** plain dense RAG on a fixed query set is the control experiment; add one improvement at a time.
- **Chunking strategies:**

| Strategy | Splits on | Best for | Watch out |
|---|---|---|---|
| Fixed-size (+ overlap) | N chars/tokens | Prototypes | Cuts words and rules |
| Recursive | Paragraph → sentence → word | General default | Ignores headings unless given separators |
| Structure-aware | Headings, sections, FAQ items, tables | Policies, FAQs, wikis | Needs per-format parsing |
| Semantic | Jumps in embedding distance between neighbouring sentences | Long text without headings | Model-specific threshold, more compute; use only if eval shows a gain |
| Parent-child | Search small children, return the parent | Conditions and actions spread across sentences | Two stores, more tokens |

- **Chunk metadata:** `document_id`, `section_path`, `chunk_id`, `source_version`, `updated_at`, `product`, `locale`, `status`, access scope.

### 🏢 Real-world example
Dense returns A, B, D, L and BM25 returns B, A, M, L. RRF gives A, B, L, D and the reranker gives **D**, A, L, B, so top-2 = D, A reaches the LLM. Without the reranker, the answer in D would have been cut. In a Zomato FAQ, structure-aware chunking keeps "money debited but order failed → check pending/reversed/refunded → raise an issue" as one complete chunk, while 120-character fixed chunks split the condition from the action.

### 🛠️ Code reference
```python
from langchain_text_splitters import RecursiveCharacterTextSplitter
# Structure-aware via separators: H2 → H3 → paragraph → line → sentence → word
splitter = RecursiveCharacterTextSplitter(
    chunk_size=800, chunk_overlap=120,
    separators=["\n## ", "\n### ", "\n\n", "\n", ". ", " "],
)

# Reciprocal Rank Fusion
def rrf(*ranked_lists, k=60):
    scores = {}
    for lst in ranked_lists:
        for rank, doc in enumerate(lst, start=1):
            scores[doc] = scores.get(doc, 0) + 1 / (k + rank)
    return sorted(scores, key=scores.get, reverse=True)

rrf(["A", "B", "D", "L"], ["B", "A", "M", "L"])   # -> A, B, L, D, M
```

### 🧪 Practice tasks
1. Chunk the same policy doc with fixed-size (120/20), recursive and heading separators. Count the chunks that hold a complete rule.
2. Run `rrf()` on two lists of your own and check the result by hand.
3. Build a 10-query baseline (dense only) and record Recall@4 and Precision@4 before changing anything.
4. Try LangChain's `SemanticChunker` (langchain-experimental) on a paragraph without headings, and see where it cuts.
5. Set up `ParentDocumentRetriever` and compare the answers against plain chunk retrieval.

---

## 9. Dense vs Sparse Retrieval & BM25

### 📘 Theory
| | Dense | Sparse (BM25) |
|---|---|---|
| Vector | Fixed width (e.g. 1536), every slot a float | Vocabulary width (~50k), almost all zeros |
| A slot means | Nothing alone; meaning is spread across all slots | One specific word |
| Strong at | Paraphrases, synonyms, natural language | Exact codes, IDs, names, rare terms |
| Weak at | Unseen codes (`PAY-403`, `ZM-401`) | Different words for the same idea |
| Index | ANN (HNSW) over float arrays | Inverted index (term → postings list) |

- **BM25** = TF (diminishing returns) × IDF (rare words worth more) with length normalisation; knobs `k1` (saturation) and `b` (length penalty).
- **Hybrid** = run both in parallel, fuse with **RRF** `Σ 1/(60 + rank)` (scores are on different scales, so fuse ranks).

### 🏢 Real-world example
Partner query "dashboard says PAY-403": dense returns AUTH-012 (0.91), PAY-021 (0.86), ERR-008 (0.79) and misses ERR-403, the only article naming the code. For "error ZM-401 coupon", dense puts ZH-013 at #2 while BM25 puts it at #1; RRF puts it at #1 overall.

### 🛠️ Code reference
```python
from langchain_qdrant import FastEmbedSparse
from langchain_openai import OpenAIEmbeddings

dense_embeddings = OpenAIEmbeddings(model="openai/text-embedding-3-small",
                                   openai_api_base="https://openrouter.ai/api/v1",
                                   api_key=os.environ["OPENROUTER_API_KEY"])
sparse_embeddings = FastEmbedSparse(model_name="Qdrant/bm25")   # local, no API
DENSE_DIM = len(dense_embeddings.embed_query("probe"))        # → 1536, use as the collection size
len(sparse_embeddings.embed_query("refund status FAQ").indices)   # → a few non-zero terms
```

### 🧪 Practice tasks
1. Embed "refund status FAQ" both ways and print the dense length vs the sparse `indices`/`values`.
2. Add an article that mentions an error code once, then query by the code: compare the dense top-3 against BM25.
3. Rewrite a query with synonyms only ("money not returned" vs "refund not received") and see which retriever still finds it.
4. Compute RRF by hand for two 5-item lists and check it with the `rrf()` helper from section 8.

---

## 10. Contextual Retrieval, Parent-Child & Query Intelligence

### 📘 Theory
- **Contextual retrieval:** an LLM prepends "where this chunk comes from" to every chunk before embedding and BM25 indexing. Anthropic measured top-20 retrieval failures of 5.7% → 3.7% (−35%), and → 2.9% (−49%) with contextual BM25. Costs one LLM call per chunk; measure before adopting.
- **Parent-child:** search ~300-char children, return the ~1000-char parent. `ParentDocumentRetriever` is in langchain-classic (security fixes only until Dec 2026), so own the pattern.
- **Choosing a mode:** paraphrase → dense; codes/IDs → sparse; both → hybrid; scope → metadata filters; no answer → threshold + abstain; near-duplicates → rerank.
- **Query intelligence:**

| Technique | What | Guardrail |
|---|---|---|
| Rewriting | Follow-up → standalone query from history | Keep IDs, add no facts, answer with the original question, evaluate |
| Self-query | LLM extracts semantic query + filters | Allowlist fields; tenant/role from auth only |
| Routing | Pick the system: RAG, live API, analytics, action workflow | Validate the route against an allowlist; fall back to "all" |
| Multi-query / HyDE / step-back | More phrasings / hypothetical answer / broader question | Costs extra LLM calls; measure |

### 🏢 Real-world example
"What if it has already passed?" retrieves cancellation and refund noise (0.52). Rewritten to "What should I do if the estimated arrival time for my Zomato order has already passed?", ZH-001 Late delivery ranks #1 (0.86). A self-query proposal with `tenant_id: partner-x` is rejected because the tenant comes from authentication.

### 🛠️ Code reference
```python
class SearchQuery(BaseModel):
    query: str = Field(min_length=3, max_length=400)

rewrite_chain = ChatPromptTemplate.from_messages([
    ("system", "Rewrite the latest user message as a standalone search query. "
               "Use history only to resolve references. Do not answer or invent facts."),
    ("human", "Conversation history:\n{history}\nLatest message: {question}"),
]) | llm.with_structured_output(SearchQuery)
candidates = retriever.invoke(rewrite_chain.invoke({"history": h, "question": q}).query)

router_chain = router_prompt | llm | JsonOutputParser()      # -> {"area": "wiki"}
area = router_chain.invoke({"question": q}).get("area")
area = area if area in ALLOWED_AREAS else None             # None = search all
```

### 🧪 Practice tasks
1. Write a contextualiser prompt, enrich 10 chunks, and compare hybrid results before and after on your eval set.
2. Build `ParentDocumentRetriever` (300/1000) on a runbook and print child vs parent length for a rollback question.
3. Feed the rewrite chain "order ZM-123 failed after payment was debited" and confirm the ID survives.
4. Make the router return an invalid area on purpose and confirm the fallback searches everything.
5. Write a self-query validator that drops any non-allowlisted field and always injects tenant_id from the session.

---

## 11. Reranking, RAG Security & Evaluation

### 📘 Theory
- **Reranking:** after hybrid + RRF, a **cross-encoder** scores each (query, chunk) pair in one API call; sort, keep the top K. Bi-encoder (embeddings) = separate vectors, fast, precomputed; cross-encoder = reads both together, accurate, per pair at query time, so retrieve 20–50 and rerank to 3–5. Providers: Voyage AI (MongoDB), Cohere, BGE/Jina (self-host).
- **Security:** *authorisation before evidence reaches the model.* Every chunk carries access metadata (tenant, audience, role, status); the server builds a mandatory deterministic filter from the authenticated session. The LLM is not a security boundary. Also: allowlisted self-query fields, PII redaction at indexing, retrieved text treated as data (prompt-injection defence), masked logs, actions via authorised workflows.
- **Evaluation:** golden set → measure retrieval (Recall@K, Precision@K, hit rate, MRR, nDCG) and generation (faithfulness, answer relevance, context precision/recall, citation accuracy, correct abstention; LLM-as-judge/RAGAS) plus latency/cost/errors. One change at a time; CI gate.

### 🏢 Real-world example
A consumer asks about payout delays; an internal partner-ops record is worded almost identically. Without an `audience` filter it's retrieved and quoted, which is a leak. With `must: tenant_id = session.tenant, audience ∈ ["consumer"]` it can never be searched. Adding a reranker is kept only if Recall@3 / nDCG improve on the golden set without breaking p95 latency.

### 🛠️ Code reference
```python
# Rerank (Voyage AI; check current model names)
import voyageai
vo = voyageai.Client()
res = vo.rerank(query=q, documents=[c.page_content for c in cands], model="rerank-2.5", top_k=3)
top = [cands[r.index] for r in res.results]

# Server-built access filter (Qdrant)
flt = models.Filter(must=[
    models.FieldCondition(key="tenant_id", match=models.MatchValue(value=session.tenant_id)),
    models.FieldCondition(key="audience",  match=models.MatchAny(any=session.allowed_audiences)),
    models.FieldCondition(key="status",    match=models.MatchValue(value="published")),
])

# MRR over a golden set
def mrr(results, golden):   # results: {qid: [chunk_ids]}, golden: {qid: set(relevant_ids)}
    total = 0
    for qid, ranked in results.items():
        total += next((1 / i for i, c in enumerate(ranked, 1) if c in golden[qid]), 0)
    return total / len(results)
```

### 🧪 Practice tasks
1. Retrieve 20 for 10 questions, rerank to 3, and compare Recall@3 with and without the reranker.
2. Kill the rerank call (bad key) and confirm the pipeline falls back to the RRF order.
3. Index one "internal" doc with `audience=internal` and prove a consumer session can never retrieve it.
4. Plant "ignore previous instructions" in a test doc and check the answer stays grounded.
5. Build a 30-question golden set (codes, follow-ups, other-tenant traps, unanswerable) and compute MRR + faithfulness.

