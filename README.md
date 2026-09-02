# douyamv-170hx-80g

[中文版](README.zh-CN.md)

Solution knowledge base for the NVIDIA CMP 170HX 80G unlock project.

One numbered entry per problem. Every entry has five elements:
**what error it solves / the exact change / how to verify (which log line) /
dependencies / pitfalls**. Numbers follow the experimental progression;
later entries depend on earlier ones.

## Index

| # | Status |
|---|---|
| [0001](0001/) | ✅ published |
| [0002](0002/) | ✅ published |
| 0003 – 0011 | not public |
| [0012](0012/) | ✅ published |
| 0013 – 0014 | not public |
| [0015](0015/) | ✅ published |
| 0016 | not public |
| 9999 | not public |

> Unpublished directories keep only their number — no titles, no content.
>
> **Contact**: If your own research has gone further than this project, open an
> **Issue** and share your results first (post your findings/evidence), or reach
> out privately to exchange them. In particular we would like to compare notes
> on the **data-layer folding**: whether you still observe address aliasing
> beyond ~39 GB after geometry unlock, and how (or whether) you resolved it.

## Published

- **0001** — the HS ROP fire channel (infrastructure)
- **0002** — 80G geometry unlock (CFG1/LMR/SS/CSTATUS)
- **0012** — boot gate hash maintenance
- **0015** — single source of truth (config shadowing)

Entry contents are written in Chinese; this top-level README is provided
in English with a Chinese version linked above.

## License

MIT
