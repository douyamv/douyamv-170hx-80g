#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdlib.h>

/* 文档「关键寄存器最终值」表:
 *   CSTATUS(per-FBPA)  base+0x20C  = 0x00001000  → 4096MiB/FBPA × 20 = 80GB
 * 广播别名读到的是 0x1000，但真正决定容量的是每个 FBPA 实例自己的值。
 * 若只有一半实例报 4096MiB，容量就正好砍半 —— 与实测 39GiB 吻合。
 */
static volatile uint32_t *R;
static uint32_t rd(uint32_t o) { return R[o / 4]; }
static int dead(uint32_t v) { return v == 0xffffffffu || (v & 0xffff0000u) == 0xbadf0000u; }

int main(int argc, char **argv)
{
    uint32_t base   = argc > 1 ? (uint32_t)strtoul(argv[1], 0, 16) : 0x900000;
    uint32_t stride = argc > 2 ? (uint32_t)strtoul(argv[2], 0, 16) : 0x4000;

    int fd = open("/sys/bus/pci/devices/0000:81:00.0/resource0" /* 按本机lspci改BDF,如0000:01:00.0 */, O_RDONLY | O_SYNC);
    if (fd < 0) { perror("open"); return 1; }
    R = (volatile uint32_t *)mmap(0, 0x1000000, PROT_READ, MAP_SHARED, fd, 0);
    if (R == MAP_FAILED) { perror("mmap"); return 2; }

    printf("广播: CFG1(0x9a0204)=0x%08x  CSTATUS(0x9a020c)=0x%08x\n\n",
           rd(0x9a0204), rd(0x9a020c));

    printf("per-FBPA (base=0x%06x stride=0x%x):\n", base, stride);
    printf("  #   CSTATUS(+0x20C)  CFG1(+0x204)   容量\n");
    int alive = 0, full = 0;
    unsigned long long totalMB = 0;
    for (int i = 0; i < 24; i++) {
        uint32_t b  = base + (uint32_t)i * stride;
        uint32_t cs = rd(b + 0x20c);
        uint32_t c1 = rd(b + 0x204);
        if (dead(cs) && dead(c1)) continue;
        alive++;
        totalMB += cs;                    /* CSTATUS 单位是 MiB */
        if (cs == 0x1000) full++;
        printf("  %2d  0x%08x       0x%08x     %u MiB%s\n",
               i, cs, c1, cs, (cs == 0x1000) ? "  <= 4096(满)" : "");
    }
    printf("\n存活 FBPA=%d  其中 4096MiB=%d  容量合计=%llu MiB (%.2f GiB)\n",
           alive, full, totalMB, totalMB / 1024.0);
    return 0;
}
