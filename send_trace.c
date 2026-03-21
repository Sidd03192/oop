/**
 * fpga_trace_send.c
 *
 * Protocol (matches memory_subsystem.sv):
 *
 *   1. Open /dev/mem and mmap the FPGA peripheral region.
 *   2. Read 16 bytes (121 bits packed into 4 x 32-bit chunks) from the
 *      binary trace file.
 *   3. Wait for trace_ready == 1  (hardware is not back-pressuring).
 *   4. Write all four chunks via (trace_addr, trace_data) register pairs,
 *      one at a time, in order 0 → 3.  trace_valid is NOT asserted yet.
 *   5. Assert trace_valid = 1.
 *   6. Wait for trace_ready == 1  (confirms trace_fire inside the module).
 *   7. De-assert trace_valid = 0.
 *   8. Repeat from step 2 for the next record.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

/* ── FPGA memory map ─────────────────────────────────────────────────── */
#define HW_REGS_BASE        0xFF200000u
#define HW_REGS_SPAN        0x00200000u

/* Trace peripheral sits at offset 0 within the HW region */
#define TRACE_BASE_OFFSET   0x00000000u

/*
 * Byte offsets of each register inside the trace peripheral block.
 *
 *  +0x0  trace_addr  [1:0]   – selects which 32-bit chunk (0-3)
 *  +0x4  trace_data  [31:0]  – 32-bit chunk payload
 *  +0x8  trace_valid [0]     – assert AFTER all chunks are loaded
 *  +0xC  trace_ready [0]     – read-only back-pressure from hardware
 */
#define OFF_TRACE_ADDR      0x0u
#define OFF_TRACE_DATA      0x4u
#define OFF_TRACE_VALID     0x8u
#define OFF_TRACE_READY     0xCu

/* Chunk 3 carries bits [120:96] — only the low 25 bits are valid */
#define CHUNK3_MASK         0x01FFFFFFu

/* Number of 32-bit words per trace record (4 × 32 = 128 bits ≥ 121 bits) */
#define CHUNKS_PER_TRACE    4u

/* ── Low-level MMIO ──────────────────────────────────────────────────── */
static inline void mmio_write(void *base, uint32_t byte_off, uint32_t val)
{
    *((volatile uint32_t *)((uint8_t *)base + byte_off)) = val;
}

static inline uint32_t mmio_read(void *base, uint32_t byte_off)
{
    return *((volatile uint32_t *)((uint8_t *)base + byte_off));
}

/* ── Handshake helpers ───────────────────────────────────────────────── */

/* Block until the hardware signals it is ready to accept input. */
static void wait_for_ready(void *trace_base)
{
    while (!(mmio_read(trace_base, OFF_TRACE_READY) & 1u))
        ;
}

/* ── Core send routine ───────────────────────────────────────────────── */

/**
 * send_trace_record() - full handshake for one 121-bit trace record.
 *
 * @trace_base : mmap'd pointer to the start of the trace register block.
 * @chunk      : four 32-bit words packed from the binary trace file:
 *
 *   chunk[0]  → addr 0 → trace_line[31:0]
 *   chunk[1]  → addr 1 → trace_line[63:32]
 *   chunk[2]  → addr 2 → trace_line[95:64]
 *   chunk[3]  → addr 3 → trace_line[120:96]  (bits [120:96], 25 bits used)
 *
 * Step 1 – Wait for trace_ready (hardware idle).
 * Step 2 – Write each chunk: set trace_addr then trace_data, repeat × 4.
 *           trace_valid stays 0 throughout this phase so the hardware does
 *           NOT fire; it merely fills trace_line registers.
 * Step 3 – Assert trace_valid = 1.
 *           trace_fire = trace_valid & trace_ready pulses inside the RTL,
 *           committing trace_line to the LSQ / TLB.
 * Step 4 – Wait for trace_ready = 1 again (fire acknowledged).
 * Step 5 – De-assert trace_valid = 0, ready for the next record.
 */
static void send_trace_record(void *trace_base, const uint32_t chunk[4])
{

    /* ── Step 2: load all four chunks (trace_valid stays 0) ─────────── */
    for (uint8_t addr = 0; addr < CHUNKS_PER_TRACE; addr++) {
        uint32_t data = chunk[addr];

        /* Chunk 3 carries bits [120:96] — mask away unused upper bits */
        if (addr == 3)
            data &= CHUNK3_MASK;

        printf("Writing Addr: 0x%x\n", addr);
        /* set chunk select */
        mmio_write(trace_base, OFF_TRACE_ADDR, addr);

        printf("Addr Written: 0x%x\n", mmio_read(trace_base, OFF_TRACE_ADDR));

        printf("Writing Data Chunk: 0x%x\n", data);
        /* write data — this pulses trace_data_write_pulse in the RTL
        which clocks the chunk into trace_line on the next rising edge */
        mmio_write(trace_base, OFF_TRACE_DATA, data);

        printf("Data Written: 0x%x\n", mmio_read(trace_base, OFF_TRACE_DATA));

        usleep(1);
    }

    printf("Asserting Valid\n");
    /* ── Step 3: assert trace_valid — triggers trace_fire in RTL ─────── */
    mmio_write(trace_base, OFF_TRACE_VALID, 1u);

     printf("Waiting for ready\n");
    /* ── Step 1: wait for hardware to be ready ───────────────────────── */
    wait_for_ready(trace_base);

    printf("De-asserting valid\n");
    /* ── Step 5: de-assert trace_valid ──────────────────────────────── */
    mmio_write(trace_base, OFF_TRACE_VALID, 0u);
}

/* ── Binary file reader ──────────────────────────────────────────────── */

/**
 * read_chunks_from_file() - reads exactly 16 bytes from fp into chunk[4].
 *
 * The binary trace file stores records as four consecutive little-endian
 * 32-bit words (matching the hardware chunk order).
 *
 * Returns 1 on success, 0 on clean EOF, -1 on read error.
 */
static int read_chunks_from_file(FILE *fp, uint32_t chunk[4])
{
    size_t n = fread(chunk, sizeof(uint32_t), CHUNKS_PER_TRACE, fp);

    if (n == CHUNKS_PER_TRACE)
        return 1;           /* full record read */

    if (feof(fp) && n == 0)
        return 0;           /* clean end of file */

    /* Partial read or I/O error */
    fprintf(stderr, "Error: incomplete trace record (%zu/4 words read): %s\n",
            n, ferror(fp) ? strerror(errno) : "unexpected EOF");
    return -1;
}

/* ── FPGA handle ─────────────────────────────────────────────────────── */
typedef struct {
    int   fd;
    void *hw_base;      /* full HW_REGS_SPAN mmap                */
    void *trace_base;   /* pointer into hw_base + TRACE_BASE_OFFSET */
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

/* ── main ────────────────────────────────────────────────────────────── */
int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <trace_file.bin>\n", argv[0]);
        return EXIT_FAILURE;
    }

    /* Open and map the FPGA peripheral region */
    fpga_handle_t fpga;
    if (fpga_open(&fpga) < 0)
        return EXIT_FAILURE;

    /* Open the binary trace file */
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        perror("fopen");
        fpga_close(&fpga);
        return EXIT_FAILURE;
    }

    uint32_t chunk[4];
    size_t   records_sent = 0;
    int      rc;

    printf("Sending traces from: %s\n", argv[1]);

    /* Process one 121-bit record at a time */
    while ((rc = read_chunks_from_file(fp, chunk)) == 1) {

        send_trace_record(fpga.trace_base, chunk);
        records_sent++;

        printf("  [%5zu] chunk[0]=0x%08X chunk[1]=0x%08X "
               "chunk[2]=0x%08X chunk[3]=0x%08X\n",
               records_sent,
               chunk[0], chunk[1], chunk[2], chunk[3] & CHUNK3_MASK);
    }

    if (rc == -1)   /* I/O error already printed */
        goto cleanup;

    printf("\nDone. %zu record(s) sent to FPGA.\n", records_sent);

cleanup:
    fclose(fp);
    fpga_close(&fpga);
    return (rc < 0) ? EXIT_FAILURE : EXIT_SUCCESS;
}