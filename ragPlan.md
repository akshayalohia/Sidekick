# Unified Brain RAG System - Implementation Plan

## Executive Summary

This document outlines a comprehensive redesign of Sidekick's RAG system to transform it from fragmented "experts" into a unified personal assistant "brain" with intelligent retrieval.

**Goal:** Create a local personal assistant that:
1. Has a single unified knowledge base (emails, notes, documents - everything personal)
2. Uses RAG intelligently - only when relevant, not overwhelming the LLM
3. Maintains memory from previous chats (semantic, episodic, procedural)
4. Runs locally on a modern MacBook
5. Has high real-world accuracy and utility

---

## Part 1: Architecture Overview

### Current State (Problems)

| Component | Current Implementation | Limitation |
|-----------|----------------------|------------|
| **Experts** | Separate knowledge bases per expert | Fragmented knowledge, no unified view |
| **Retrieval** | Pure vector (DistilBERT) | Misses keyword matches, rare terms |
| **Ranking** | Simple score + 0.1/0.05 boosts | No semantic reranking |
| **Memory** | Single "The user..." extraction | No temporal decay, no episodic context |
| **Query Routing** | None - always retrieves | RAG overwhelms non-personal queries |
| **Chunk Size** | 1024 chars fixed | Too coarse for some content |

### Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER QUERY                                       │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    QUERY ROUTER (Classifier)                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ PERSONAL    │  │ GENERAL     │  │ MEMORY      │  │ HYBRID      │    │
│  │ (full RAG)  │  │ (no RAG)    │  │ (recall)    │  │ (light RAG) │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────┐
        │ PERSONAL               │ HYBRID                 │ GENERAL
        ▼                        ▼                        ▼
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│  HYBRID RETRIEVAL │   │  MEMORY ONLY +    │   │  PURE LLM         │
│  BM25 + Vector    │   │  Light Context    │   │  (no retrieval)   │
│  + Graph Traverse │   │                   │   │                   │
└─────────┬─────────┘   └─────────┬─────────┘   └─────────┬─────────┘
          │                       │                       │
          ▼                       │                       │
┌───────────────────┐             │                       │
│  CROSS-ENCODER    │             │                       │
│  RERANKER         │             │                       │
│  (BGE-reranker)   │             │                       │
└─────────┬─────────┘             │                       │
          │                       │                       │
          ▼                       ▼                       │
┌───────────────────────────────────────────────┐        │
│            CONTEXT ASSEMBLER                   │        │
│  - Memory (semantic + episodic)               │        │
│  - RAG results (if applicable)                │        │
│  - Conversation history                       │        │
└─────────────────────┬─────────────────────────┘        │
                      │                                   │
                      ▼                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         LLM INFERENCE                                    │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    MEMORY EXTRACTION                                     │
│  (Post-response: extract facts, update episodic memory)                 │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 2: Query Routing - The Critical Gate

### Why This Matters Most

The #1 problem with personal assistant RAG is **over-retrieval**. When you ask "What's the capital of France?", the system shouldn't waste time searching your emails. Query routing is the intelligence layer that decides:

- **Route A**: Personal query → Full RAG pipeline
- **Route B**: General knowledge → Pure LLM, no retrieval
- **Route C**: Memory recall → Just memories, no document RAG
- **Route D**: Hybrid → Light RAG + memories

### Implementation: Semantic Router

**Query Intent Classification:**

```swift
enum QueryIntent: String {
    case personal       // "What did John email me about the project?"
    case memory         // "What's my favorite restaurant?"
    case general        // "Explain quantum computing"
    case hybrid         // "Help me write an email to my boss"
}
```

**Classification Method:**
- Keyword signal matching (personal signals: "my", "email", "meeting", etc.)
- Phrase detection ("told me", "last week", "what is", "help me write")
- Confidence scoring with fallback to hybrid when uncertain

### Benefits
- **Speed**: No retrieval for general queries (saves 500ms-2s)
- **Accuracy**: RAG doesn't pollute general knowledge answers
- **Cost**: Fewer tokens when not needed

---

## Part 3: Hybrid Retrieval System

### Why Hybrid Beats Pure Vector

**Example failures of pure vector search:**
- "Find email from invoice #INV-2024-0847" → Vector doesn't match invoice numbers
- "What did ACME Corp say?" → Proper nouns get fuzzy matches
- "Meeting on 2024-11-15" → Dates aren't semantically similar

### Implementation: BM25 + Vector with RRF Fusion

**BM25 Index:**
- Okapi BM25 algorithm for keyword search
- Parameters: k1=1.5 (term frequency saturation), b=0.75 (length normalization)
- Inverted index for fast lookup
- Stopword filtering

**Reciprocal Rank Fusion (RRF):**
```
RRF_score = Σ (1 / (k + rank_i))
```
Where k=60 (standard value) and rank_i is the rank from each retrieval method.

### Benefits
- Catches exact matches (invoice numbers, names, dates)
- Maintains semantic understanding
- RRF is parameter-free and robust

---

## Part 4: Cross-Encoder Reranking

### Why Reranking is Critical

Cross-encoders process query and document together, enabling richer token-level interactions compared to bi-encoders (which encode separately).

### Implementation Options for MacBook

| Model | Size | Speed (CPU) | Best For |
|-------|------|-------------|----------|
| `bge-reranker-base` | 278M | ~50ms/pair | Good balance |
| `bge-reranker-v2-m3` | 568M | ~100ms/pair | Best multilingual |
| `bge-reranker-v2.5-gemma2-lightweight` | ~1.5GB | ~200ms/pair | Best accuracy |

**Recommendation**: Use `bge-reranker-base` for MacBook deployment.

**Alternative**: LLM-as-reranker (slower but no extra model needed)

---

## Part 5: Unified Knowledge Brain

### Replacing Experts with a Single Brain

**Current Problem**: Experts fragment your knowledge. Asking "What did I discuss with John about the budget?" requires knowing which expert to query.

**Solution**: One unified knowledge base with automatic categorization.

### Source Categories (for filtering, not separation)
- email, notes, documents, calendar, messages, web, other

### Smart Chunking Strategy
- Optimal chunk sizes: 256-512 tokens (research-backed)
- Adaptive chunking based on content type:
  - Emails: Preserve structure (headers, body, signature)
  - Notes: Respect paragraph boundaries
  - Documents: Semantic chunking at topic shifts
  - Calendar: Each event as one chunk

---

## Part 6: Three-Tier Memory System

Based on cognitive science research:

### Memory Types

| Type | Purpose | Storage | Retrieval |
|------|---------|---------|-----------|
| **Semantic** | Facts about user | Vector DB | Similarity search |
| **Episodic** | Past successful interactions | Timestamped DB | Recency + relevance |
| **Procedural** | Learned behaviors/preferences | Rules DB | Pattern matching |

### Semantic Memory
- Facts: "The user prefers dark mode", "The user works at ACME Corp"
- Categories: preference, personal_info, relationship, opinion, behavior
- Confidence scoring (0-1)
- Temporal decay (30-day half-life for recency boost)
- Access frequency boost

### Episodic Memory
- Stores: user query, response summary, was_helpful flag, context, timestamp
- Embedding for similarity search
- Boost for helpful interactions
- Max 500 memories (rolling window)

### Procedural Memory
- Trigger patterns and associated behaviors
- Success rate tracking
- Example: "When user asks to write email → use formal tone"

### Memory Consolidation
- Periodic deduplication
- Decay of old/unused memories
- Promotion of episodic patterns to procedural

---

## Part 7: Knowledge Graph Improvements

### Current Limitations
1. Simple connected-component clustering → Use Leiden algorithm
2. No entity deduplication across sources → Global entity resolution
3. Community summaries not query-aware → Dynamic summarization

### Enhanced Features
- Entity resolution across all sources (canonical ID, aliases)
- Enhanced relationships with co-occurrence counting
- Query-aware community summaries (cached)

---

## Part 8: Context Assembly and Token Management

### The Problem
RAG systems often stuff too much context, leading to:
- Token budget exceeded
- Important info buried in noise
- LLM confusion from contradictory sources

### Smart Context Assembly

**Token Budget Allocation (for 8K context):**
- System prompt: 12.5% (~1000 tokens)
- Memory: 6.25% (~500 tokens)
- RAG context: 25% (~2000 tokens)
- Conversation history: 25% (~2000 tokens)
- Response buffer: 25% (~2000 tokens)

**Optimization Strategy:**
1. Remove oldest conversation turns first
2. Truncate RAG context
3. Truncate memory
4. Never touch system prompt

---

## Implementation Progress

### ✅ Completed (Phase 1-4)

| Component | File | Status |
|-----------|------|--------|
| **QueryRouter** | `Logic/Routing/QueryRouter.swift` | ✅ Complete |
| **BM25Index** | `Logic/Retrieval/BM25Index.swift` | ✅ Complete |
| **HybridRetriever** | `Logic/Retrieval/HybridRetriever.swift` | ✅ Complete |
| **KnowledgeBrain** | `Logic/Data Models/KnowledgeBrain.swift` | ✅ Complete |
| **UnifiedMemory** | `Logic/Memory/UnifiedMemory.swift` | ✅ Complete |
| **ContextAssembler** | `Logic/Context/ContextAssembler.swift` | ✅ Complete |
| **BrainIntegration** | `Logic/Integration/BrainIntegration.swift` | ✅ Complete |
| **BrainTester** | `Logic/Utilities/BrainTester.swift` | ✅ Complete |
| **RetrievalSettings** | `Logic/Settings/RetrievalSettings.swift` | ✅ Modified |

**Total: 9 files, 2,663 lines of code**

### New Settings Added

```swift
RetrievalSettings.useUnifiedBrain      // Toggle brain vs experts mode
RetrievalSettings.useQueryRouting      // Enable/disable query classification
RetrievalSettings.useHybridSearch      // BM25 + vector vs vector only
RetrievalSettings.hybridVectorWeight   // 0-1, balance between methods
RetrievalSettings.useReranking         // Cross-encoder reranking
RetrievalSettings.chunkSize            // Default chunk size (400 chars)
```

### ⏳ Pending

| Feature | Priority | Notes |
|---------|----------|-------|
| **Cross-encoder reranking** | Medium | Requires bundling BGE model (~300MB) or LLM-as-reranker |
| **Leiden clustering** | Low | Current GraphRAG uses simpler connected components |
| **Full pipeline integration** | High | Wire into actual inference flow |
| **Debug menu** | High | Added but needs files added to Xcode target |
| **UI for brain mode toggle** | Medium | Settings view update |
| **Ingestion UI** | Medium | Easy document upload |

---

## How to Test

### 1. Add Files to Xcode Project

All new files must be added to the Sidekick target:
```
Logic/Routing/QueryRouter.swift
Logic/Retrieval/BM25Index.swift
Logic/Retrieval/HybridRetriever.swift
Logic/Data Models/KnowledgeBrain.swift
Logic/Memory/UnifiedMemory.swift
Logic/Context/ContextAssembler.swift
Logic/Integration/BrainIntegration.swift
Logic/Utilities/BrainTester.swift
```

### 2. Enable Brain Mode

```swift
RetrievalSettings.useUnifiedBrain = true
RetrievalSettings.useQueryRouting = true
RetrievalSettings.useHybridSearch = true
RetrievalSettings.useMemory = true
```

### 3. Run Tests

From Debug menu → Brain (RAG System) → Run All Tests

Or programmatically:
```swift
Task {
    await BrainTester.runAllTests()
}
```

### 4. Test Individual Components

```swift
// Query Router
let result = QueryRouter.shared.classify(query: "What is the capital of France?")
print(result.intent)  // Should be .general

let result2 = QueryRouter.shared.classify(query: "What did John email me?")
print(result2.intent)  // Should be .personal

// BM25
let bm25 = BM25Index()
bm25.addDocument(id: UUID(), text: "Invoice #INV-2024-0847", source: "docs", chunkIndex: 0)
let results = bm25.search(query: "INV-2024-0847")
print(results)  // Should find the invoice

// Brain ingestion
await KnowledgeBrain.shared.ingest(
    content: "Your document text...",
    source: "test.txt",
    category: .notes
)
```

---

## Next Steps

### Immediate (to complete implementation)

1. **Fix Xcode project** - Add all new files to Sidekick target
2. **Test in Xcode** - Run BrainTester to verify components work
3. **Wire into inference** - Update `textWithSources` to use brain when enabled
4. **Add UI toggle** - Settings view for brain mode

### Short-term (production ready)

1. **Add ingestion UI** - Drag-and-drop documents into brain
2. **Implement reranking** - Either bundle BGE model or use LLM
3. **Test with real data** - Emails, notes, documents
4. **Add feedback loop** - "Was this helpful?" to improve memory

### Long-term (optimization)

1. **Leiden clustering** - Better community detection
2. **Entity resolution** - Merge "John", "John Smith", "J. Smith"
3. **Query-aware summaries** - Dynamic community summaries
4. **Caching** - Frequent query results

---

## Sources & References

- [Stack Overflow - Practical tips for RAG](https://stackoverflow.blog/2024/08/15/practical-tips-for-retrieval-augmented-generation-rag/)
- [DataCamp - RAG and Reranking](https://www.datacamp.com/tutorial/boost-llm-accuracy-retrieval-augmented-generation-rag-reranking)
- [Analytics Vidhya - Contextual RAG with Hybrid Search](https://www.analyticsvidhya.com/blog/2024/12/contextual-rag-systems-with-hybrid-search-and-reranking/)
- [Microsoft Research - GraphRAG](https://www.microsoft.com/en-us/research/blog/graphrag-unlocking-llm-discovery-on-narrative-private-data/)
- [LangChain - Long-term Memory Concepts](https://langchain-ai.github.io/langmem/concepts/conceptual_guide/)
- [Towards Data Science - RAG Query Routing](https://towardsdatascience.com/routing-in-rag-driven-applications-a685460a7220/)
- [BAAI BGE Reranker](https://huggingface.co/BAAI/bge-reranker-base)
- [Neo4j - Advanced RAG Techniques](https://neo4j.com/blog/genai/advanced-rag-techniques/)
- [LTRR - Learning To Rank Retrievers](https://arxiv.org/html/2506.13743)
- [Stanford ColBERT](https://github.com/stanford-futuredata/ColBERT)

---

## Commit History

### Initial Implementation
```
commit: Implement unified brain RAG system with intelligent retrieval
files: 9 changed, 2663 insertions(+), 1 deletion(-)

- QueryRouter: Classifies queries to determine when RAG is needed
- BM25Index: Keyword search for exact matches
- HybridRetriever: Combines BM25 + vector with RRF fusion
- KnowledgeBrain: Unified knowledge base singleton
- UnifiedMemory: Three-tier memory system
- ContextAssembler: Smart token budgeting
- BrainIntegration: Integration layer
- BrainTester: Test utility
- RetrievalSettings: Added brain settings
```

### Subsequent Fixes
```
commit: Add standalone test file for QueryRouter logic verification
commit: Add Brain debug menu with tests and settings toggles
commit: Fix SearchResult initializer - add direct init without SimilaritySearchKit dependency
```
