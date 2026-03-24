#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define HW_REGS_BASE      0xFF200000u
#define HW_REGS_SPAN      0x00200000u
#define TRACE_BASE_OFFSET 0x00000000u

#define OFF_TRACE_ADDR    0x0u
#define OFF_TRACE_DATA    0x4u
#define OFF_TRACE_VALID   0x8u
#define OFF_TRACE_READY   0xCu
#define OFF_DEBUG_STATUS0 0x10u
#define OFF_DEBUG_STATUS1 0x14u
#define OFF_DEBUG_SQ0     0x18u

#define CHUNK3_MASK       0x01FFFFFFu
#define CHUNKS_PER_TRACE  4u
#define WAIT_POLL_LIMIT   10000000u

static inline void mmio_write(void *base, uint32_t byte_off, uint32_t val)
{
    *((volatile uint32_t *)((uint8_t *)base + byte_off)) = val;
}

static inline uint32_t mmio_read(void *base, uint32_t byte_off)
{
    return *((volatile uint32_t *)((uint8_t *)base + byte_off));
}

static void dump_debug_status(void *trace_base)
{
    uint32_t s0 = mmio_read(trace_base, OFF_DEBUG_STATUS0);
    uint32_t s1 = mmio_read(trace_base, OFF_DEBUG_STATUS1);

    printf("debug_status0 = 0x%08X\n", s0);
    printf("  trace_valid_reg            = %u\n", (s0 >> 0) & 1u);
    printf("  trace_ready_wire           = %u\n", (s0 >> 1) & 1u);
    printf("  trace_fire                 = %u\n", (s0 >> 2) & 1u);
    printf("  lsq_lq_ready               = %u\n", (s0 >> 3) & 1u);
    printf("  lsq_sq_ready               = %u\n", (s0 >> 4) & 1u);
    printf("  l1_busy_to_lsq             = %u\n", (s0 >> 5) & 1u);
    printf("  issue_buf_valid            = %u\n", (s0 >> 6) & 1u);
    printf("  l1_mshr_full               = %u\n", (s0 >> 7) & 1u);
    printf("  l2_req_pending_valid       = %u\n", (s0 >> 8) & 1u);
    printf("  l2_install_pending_valid   = %u\n", (s0 >> 9) & 1u);
    printf("  dbg_duplicate_store_id     = %u\n", (s0 >> 10) & 1u);
    printf("  bypass_l2                  = %u\n", (s0 >> 11) & 1u);
    printf("  mem_req_valid              = %u\n", (s0 >> 12) & 1u);
    printf("  mem_req_is_write           = %u\n", (s0 >> 13) & 1u);

    printf("debug_status1 = 0x%08X\n", s1);
    printf("  trace_op                   = %u\n", (s1 >> 0) & 0x7u);
    printf("  l1_state                   = %u\n", (s1 >> 3) & 0x7u);
    printf("  sq_head                    = %u\n", (s1 >> 6) & 0x7u);
    printf("  sq_tail                    = %u\n", (s1 >> 9) & 0x7u);
    printf("  sq_id8_live_count          = %u\n", (s1 >> 12) & 0xFu);

    for (uint32_t i = 0; i < 8; i++) {
        uint32_t sq = mmio_read(trace_base, OFF_DEBUG_SQ0 + (i * 4u));
        printf("  sq[%u] active=%u id=%u state=%u raw=0x%08X\n",
               i, (sq >> 7) & 1u, (sq >> 3) & 0xFu, sq & 0x7u, sq);
    }
}

static int wait_for_ready(void *trace_base)
{
    uint32_t polls = 0;

    while ((mmio_read(trace_base, OFF_TRACE_READY) & 1u) == 0u) {
        if (++polls >= WAIT_POLL_LIMIT) {
            fprintf(stderr, "Timed out waiting for trace_ready\n");
            dump_debug_status(trace_base);
            return -1;
        }
    }
    return 0;
}

static int wait_for_accept(void *trace_base)
{
    uint32_t polls = 0;

    while (mmio_read(trace_base, OFF_TRACE_VALID) & 1u) {
        if (++polls >= WAIT_POLL_LIMIT) {
            fprintf(stderr, "Timed out waiting for trace accept\n");
            dump_debug_status(trace_base);
            return -1;
        }
    }
    return 0;
}

static int send_trace_record(void *trace_base, const uint32_t chunk[4])
{
    if (wait_for_ready(trace_base) < 0)
        return -1;

    for (uint8_t addr = 0; addr < CHUNKS_PER_TRACE; addr++) {
        uint32_t data = chunk[addr];

        if (addr == 3)
            data &= CHUNK3_MASK;

        mmio_write(trace_base, OFF_TRACE_ADDR, addr);
        mmio_write(trace_base, OFF_TRACE_DATA, data);
    }

    /*
     * Submit exactly one trace request. The Avalon wrapper auto-clears this
     * register after one successful trace_valid/trace_ready handshake so the
     * same record cannot be re-fired while software is still running.
     */
    mmio_write(trace_base, OFF_TRACE_VALID, 1u);
    return wait_for_accept(trace_base);
}

static int read_chunks_from_file(FILE *fp, uint32_t chunk[4])
{
    size_t n = fread(chunk, sizeof(uint32_t), CHUNKS_PER_TRACE, fp);

    if (n == CHUNKS_PER_TRACE)
        return 1;

    if (feof(fp) && n == 0)
        return 0;

    fprintf(stderr, "Error: incomplete trace record (%zu/4 words read): %s\n",
            n, ferror(fp) ? strerror(errno) : "unexpected EOF");
    return -1;
}

typedef struct {
    int fd;
    void *hw_base;
    void *trace_base;
} fpga_handle_t;

static int fpga_open(fpga_handle_t *h)
{
    h->fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (h->fd < 0) {
        perror("open /dev/mem");
        return -1;
    }

    h->hw_base = mmap(NULL, HW_REGS_SPAN,
                      PROT_READ | PROT_WRITE,
                      MAP_SHARED, h->fd, HW_REGS_BASE);
    if (h->hw_base == MAP_FAILED) {
        perror("mmap");
        close(h->fd);
        return -1;
    }

    h->trace_base = (uint8_t *)h->hw_base + TRACE_BASE_OFFSET;
    return 0;
}

static void fpga_close(fpga_handle_t *h)
{
    munmap(h->hw_base, HW_REGS_SPAN);
    close(h->fd);
}

int main(int argc, char *argv[])
{
    fpga_handle_t fpga;
    FILE *fp;
    uint32_t chunk[4];
    size_t records_sent = 0;
    int rc;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <trace_file.bin>\n", argv[0]);
        return EXIT_FAILURE;
    }

    if (fpga_open(&fpga) < 0)
        return EXIT_FAILURE;

    fp = fopen(argv[1], "rb");
    if (!fp) {
        perror("fopen");
        fpga_close(&fpga);
        return EXIT_FAILURE;
    }

    printf("Sending traces from: %s\n", argv[1]);

    while ((rc = read_chunks_from_file(fp, chunk)) == 1) {
        if (send_trace_record(fpga.trace_base, chunk) < 0) {
            rc = -1;
            goto cleanup;
        }
        records_sent++;

        printf("[%5zu] chunk[0]=0x%08X chunk[1]=0x%08X "
               "chunk[2]=0x%08X chunk[3]=0x%08X\n",
               records_sent,
               chunk[0],
               chunk[1],
               chunk[2],
               chunk[3] & CHUNK3_MASK);
    }

    if (rc == -1)
        goto cleanup;

    printf("Done. %zu record(s) sent to FPGA.\n", records_sent);

cleanup:
    fclose(fp);
    fpga_close(&fpga);
    return (rc < 0) ? EXIT_FAILURE : EXIT_SUCCESS;
}
