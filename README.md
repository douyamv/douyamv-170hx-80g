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

## License

MIT
