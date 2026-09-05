# douyamv-170hx-80g

[中文版](README.zh-CN.md)

Solution knowledge base for the NVIDIA CMP 170HX 80G unlock project.

One numbered entry per problem. Every entry has five elements:
**what error it solves / the exact change / how to verify (which log line) /
dependencies / pitfalls**. Numbers follow the experimental progression;
later entries depend on earlier ones.

## Result

**40 GB is stably unlocked and verified. 80 GB has folding (address aliasing)
that is not yet resolved** — see entries 0013/0016 for details.

## Index

| # | Status |
|---|---|
| [0001](0001/) | ✅ HS ROP fire channel (infrastructure) |
| [0002](0002/) | ✅ 80G geometry unlock (CFG1/LMR/SS/CSTATUS) |
| [0003](0003/) | ✅ BAR1 64GB window |
| [0004](0004/) | ✅ Folding elimination, pre-bootstrap timing (+ verification tools) |
| [0005](0005/) | ✅ WPR low-region anchoring |
| [0006](0006/) | ✅ PMA high-region registration |
| [0007](0007/) | ✅ Reverse allocation (high→low) |
| [0008](0008/) | ✅ 2MB huge pages (both sides) |
| [0009](0009/) | ✅ Page-table pool sized for 2MB |
| [0010](0010/) | ✅ PTE pool minimum reserve (192MB) |
| [0011](0011/) | ✅ sysmembar A/B verdict |
| [0012](0012/) | ✅ Boot gate hash maintenance |
| [0013](0013/) | 🔒 not public |
| [0014](0014/) | 🔒 not public |
| [0015](0015/) | ✅ Single source of truth (config shadowing) |
| [0016](0016/) | ✅ 64KB page promotion |
| [9999](9999/) | ✅ Hardware operation procedures |

Entry contents are written in Chinese. This top-level README is provided in
English with a Chinese version linked above.


## 8GB vs 10GB Variants — Comparison

> **The 10GB variant is the one to get.** Its memory subsystem is the single
> biggest differentiator: **up to 1.9 TB/s of bandwidth** (5120-bit HBM2e @ 3.0
> Gbps) — roughly 12× an RTX 4090 and ~2.4 TB/s+ is achievable in some samples
> with tuning. This is why the card performs far beyond its price class for
> LLM inference, where tokens/s is bandwidth-bound.

| Spec | CMP 170HX **8GB** | CMP 170HX **10GB** |
|---|---|---|
| **Memory bandwidth** | ~1.6 TB/s (4096-bit HBM2e) | **~1.9 TB/s (5120-bit HBM2e @ 3.0 Gbps)** ⭐ |
| Memory size (stock) | 8 GB HBM2e | 10 GB HBM2e |
| Memory size (unlocked, this project) | up to 64 GB addressable | up to 80 GB addressable |
| GPU die | GA100 (A100 silicon) | GA100 (A100 silicon) |
| SMs / Tensor Cores | 108 / 432 (die full, unlockable) | 108 / 432 (die full, unlockable) |
| FP32 | ~19.5 TFLOPS (unlocked) | ~19.5 TFLOPS (unlocked) |
| FP16 Tensor | ~77 TFLOPS (unlocked) | ~77 TFLOPS (unlocked) |
| FP16 Tensor (stock) | ~6.3 TFLOPS (firmware-capped) | ~6.3 TFLOPS (firmware-capped) |
| NVLink | none (disabled) | none (disabled) |
| PCIe | Gen1 x16 stock → Gen2 unlocked | Gen1 x16 stock → Gen2 unlocked |
| TDP | 250 W | 250 W |
| Typical LLM use | 40 GB workable, folding above | 40 GB workable, folding above |

### Why bandwidth dominates

LLM inference (token generation) is memory-bandwidth bound: every generated
token requires streaming the full model weights through the memory
subsystem. A card with 1.9 TB/s feeds weights ~19% faster than a 1.6 TB/s
card at the same compute — which translates directly into ~19% more
tokens/s on large models that don't fit in cache.

Unlocking the SM count (0001/0002 in this repo) restores the *compute*
side; the **memory subsystem was never crippled** on either variant, but the
10GB variant simply has a wider bus. That's a hardware difference you can't
unlock your way around — pick the 10GB card if bandwidth matters to you.

## License

MIT
