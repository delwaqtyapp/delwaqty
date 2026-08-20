# Local Coding Model Selection — DNP-NX9 ARM64

## Date: 2026-08-20

## Device Constraints

- ARM64 / aarch64, 8 CPU cores
- ~11 GB RAM total, ~3.58 GB MemAvailable (varies)
- ~134 GB free storage
- Limited internet bandwidth
- Must NOT break existing systems

## Candidate Comparison

| Model | Params | GGUF Q4_K_M | RAM Needed | Fits? | Context | Tool Calling | Coding | License |
|-------|--------|-------------|------------|-------|---------|--------------|--------|---------|
| Qwen3.5-2B | 2B | 1.40 GB | ~2.9 GB | YES | 262K | Native | Good | Apache 2.0 |
| Gemma 4 E2B | 2.3B eff (5.1B total) | 3.11 GB | ~4.6 GB | NO | 128K | Native | Good | Apache 2.0 |
| xLAM-2-1b | 1B | 986 MB | ~2 GB | YES | 32K | Excellent | Unknown | CC-BY-NC-4.0 |
| xLAM-2-3b | 3B | 1.93 GB | ~3.1 GB | Tight | 32K | Excellent | Unknown | CC-BY-NC-4.0 |
| Qwen3-4B | 4B | ~3.4 GB | ~4.9 GB | NO | Unknown | Yes | Good | Apache 2.0 |

## Key Findings

1. **Gemma 4 E2B**: 3.11GB GGUF + KV cache + overhead = ~4.6GB needed. Only 3.58GB available. **NO-GO**.
2. **Qwen3-4B**: ~3.4GB GGUF + overhead = ~4.9GB needed. **NO-GO**.
3. **xLAM-2 models**: CC-BY-NC-4.0 license (non-commercial). Purpose-built for tool calling but only 32K context.
4. **Qwen3.5-2B**: 1.40GB GGUF, fits comfortably. 262K context. Apache 2.0. Native tool calling.

## WINNER: Qwen3.5-2B

**Why it wins:**
- Fits in RAM (~2.9GB needed, ~3.58GB available)
- 262K context window (huge advantage for coding agent)
- Apache 2.0 license (no restrictions)
- Native tool calling support
- Hybrid Gated DeltaNet + Gated Attention architecture
- Multimodal (vision + text)
- Reasonable GGUF size (1.40GB)
- General purpose (coding + tool calling + agent)

**Repository:** bartowski/Qwen_Qwen3.5-2B-GGUF
**Exact GGUF:** Qwen_Qwen3.5-2B-Q4_K_M.gguf
**Quantization:** Q4_K_M
**File Size:** 1.40 GB
**Expected RAM:** ~2.9 GB (model + KV cache + overhead)
**Expected Context:** 262K tokens
**llama.cpp:** Requires latest version for Gated DeltaNet support

## Installation Plan

1. Install llama.cpp ARM64 binary (latest version)
2. Download Qwen3.5-2B Q4_K_M GGUF (1.40GB)
3. Verify file integrity
4. Start llama-server on 127.0.0.1:11434
5. Test /v1/models, /v1/chat/completions, tool calling
6. Run agent loop test
7. Integrate into OpenCode
