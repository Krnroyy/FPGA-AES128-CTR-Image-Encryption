#include "platform.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"

#define GCM_BASE          0xA0000000U
#define PROTECTED_BUFFER_BASE 0xA0020000U
#define REG_CONTROL       0x00U
#define REG_STATUS        0x04U
#define REG_BLOCKS        0x08U
#define REG_MODE          0x0CU
#define REG_KEY0          0x10U
#define REG_IV0           0x20U
#define REG_TAG0          0x30U
#define REG_EXPECTED_TAG0 0x40U
#define REG_BYTES         0x50U
#define REG_AAD0          0x54U
#define REG_AAD_BYTES     0x64U

#define CTRL_ENABLE       0x01U
#define CTRL_LOAD_IV      0x02U
#define CTRL_SOFT_RESET   0x04U
#define CTRL_CLEAR_DONE   0x08U

#define STATUS_DONE       0x02U
#define STATUS_GCM_READY  0x10U
#define STATUS_TAG_VALID  0x20U
#define STATUS_TAG_MATCH  0x40U
#define STATUS_AUTH_FAIL  0x80U
#define STATUS_OUTPUT_SUPPRESSED 0x100U

#define MODE_ENCRYPT      0U
#define MODE_DECRYPT      1U
#define MODE_AUTH_ONLY    2U

#define BUFFER_REG_CONTROL      0x00U
#define BUFFER_REG_STATUS       0x04U
#define BUFFER_REG_EXPECT_BYTES 0x08U
#define BUFFER_REG_CAPTURED     0x0CU
#define BUFFER_REG_REPLAYS      0x10U
#define BUFFER_CTRL_CAPTURE     0x01U
#define BUFFER_CTRL_REPLAY      0x02U
#define BUFFER_CTRL_ZEROIZE     0x04U
#define BUFFER_CTRL_CLEAR       0x08U
#define BUFFER_STATUS_IDLE          0x001U
#define BUFFER_STATUS_CAPTURING     0x002U
#define BUFFER_STATUS_LOCKED        0x004U
#define BUFFER_STATUS_REPLAY_BUSY   0x008U
#define BUFFER_STATUS_REPLAY_DONE   0x010U
#define BUFFER_STATUS_ZEROIZE_DONE  0x040U
#define BUFFER_STATUS_OVERFLOW      0x080U
#define BUFFER_STATUS_LENGTH_ERROR  0x100U
#define BUFFER_STATUS_WRITE_BLOCKED 0x200U
#define BUFFER_STATUS_CAPTURE_DONE  0x400U
#define PROTECTED_CHUNK_BYTES       4096U

#define PROTOCOL_VERSION  3U
#define FORMAT_RGB888     1U
#define RGB_CHANNELS      3U
#define HEADER_SIZE_BYTES 32U
#define AAD_SIZE_BYTES    16U
#define MAX_IMAGE_WIDTH   512U
#define MAX_IMAGE_HEIGHT  512U
#define MAX_IMAGE_BYTES   (MAX_IMAGE_WIDTH * MAX_IMAGE_HEIGHT * RGB_CHANNELS)
#define MAX_SESSION_TRANSACTIONS 512U
#define MAX_SESSION_IMAGES 64U
#define DMA_TIMEOUT       300000000U
#define GCM_TIMEOUT       300000000U
#define TAMPER_XOR_MASK   0x01U

static u8 input_image[PROTECTED_CHUNK_BYTES] __attribute__((aligned(64)));
static u8 encrypted_image[PROTECTED_CHUNK_BYTES] __attribute__((aligned(64)));
static u8 recovered_image[PROTECTED_CHUNK_BYTES] __attribute__((aligned(64)));

static const u32 aes_key[4] = {
    0x2B7E1516U, 0x28AED2A6U, 0xABF71588U, 0x09CF4F3CU
};

static u32 initial_iv[3];
static u32 aad_words[4];
static u32 image_width;
static u32 image_height;
static u32 image_size_bytes;
static u32 packet_sequence;
static u32 chunk_index;
static u32 total_chunks;
static u32 accepted_chunk_count;
static u32 last_completed_sequence;
static u32 expected_chunk_index;
static u32 active_sequence;
static u32 active_total_chunks;
static u32 active_width;
static u32 active_height;
static u32 active_nonce[2];
static u32 accepted_nonce_count;
static u32 accepted_nonces[MAX_SESSION_IMAGES][2];
static int image_active;
static XAxiDma axi_dma;

typedef enum {
    HEADER_ACCEPTED = 0,
    HEADER_STOP_REQUEST,
    HEADER_REJECT_MAGIC,
    HEADER_REJECT_VERSION,
    HEADER_REJECT_FORMAT,
    HEADER_REJECT_CHANNELS,
    HEADER_REJECT_FLAGS,
    HEADER_REJECT_DIMENSIONS,
    HEADER_REJECT_PAYLOAD_SIZE,
    HEADER_REJECT_SEQUENCE_ZERO,
    HEADER_REJECT_SEQUENCE_REPLAY,
    HEADER_REJECT_IV_ZERO,
    HEADER_REJECT_IV_REUSE,
    HEADER_REJECT_CHUNK_COUNT,
    HEADER_REJECT_CHUNK_ORDER,
    HEADER_REJECT_IV_CHUNK,
    HEADER_REJECT_SESSION_LIMIT
} header_result_t;

extern char inbyte(void);
extern void outbyte(char c);

static inline u64 read_arm_counter(void)
{
#ifdef HOST_SYNTAX_CHECK
    static u64 simulated_counter;
    simulated_counter += 100U;
    return simulated_counter;
#else
    u64 value;
    __asm__ volatile("isb" ::: "memory");
    __asm__ volatile("mrs %0, cntpct_el0" : "=r" (value));
    return value;
#endif
}

static inline u64 read_arm_counter_frequency(void)
{
#ifdef HOST_SYNTAX_CHECK
    return 100000000U;
#else
    u64 value;
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r" (value));
    return value;
#endif
}

static u32 pack_be32(const u8 *bytes)
{
    return ((u32)bytes[0] << 24) | ((u32)bytes[1] << 16) |
           ((u32)bytes[2] << 8) | (u32)bytes[3];
}

static u32 unpack_be16(const u8 *bytes)
{
    return ((u32)bytes[0] << 8) | (u32)bytes[1];
}

static void receive_exact(u8 *destination, u32 size)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        destination[index] = (u8)inbyte();
}

/*
 * Packet header (network byte order):
 *   0..3   magic "CHK3"
 *   4..19  authenticated metadata (AAD)
 *   20..31 96-bit IV
 *
 * AAD layout:
 *   version:u8, format:u8, channels:u8, flags:u8 (bit 0 = final),
 *   width:u16, height:u16, chunk_bytes:u16, chunk_index:u16,
 *   total_chunks:u16, image_sequence:u16
 * IV layout: session_nonce:u64 || chunk_index:u32.
 */
static const char *header_result_name(header_result_t result)
{
    switch(result)
    {
    case HEADER_REJECT_MAGIC: return "MAGIC";
    case HEADER_REJECT_VERSION: return "VERSION";
    case HEADER_REJECT_FORMAT: return "FORMAT";
    case HEADER_REJECT_CHANNELS: return "CHANNELS";
    case HEADER_REJECT_FLAGS: return "FLAGS";
    case HEADER_REJECT_DIMENSIONS: return "DIMENSIONS";
    case HEADER_REJECT_PAYLOAD_SIZE: return "PAYLOAD_SIZE";
    case HEADER_REJECT_SEQUENCE_ZERO: return "SEQUENCE_ZERO";
    case HEADER_REJECT_SEQUENCE_REPLAY: return "SEQUENCE_REPLAY";
    case HEADER_REJECT_IV_ZERO: return "IV_ZERO";
    case HEADER_REJECT_IV_REUSE: return "IV_REUSE";
    case HEADER_REJECT_CHUNK_COUNT: return "CHUNK_COUNT";
    case HEADER_REJECT_CHUNK_ORDER: return "CHUNK_ORDER";
    case HEADER_REJECT_IV_CHUNK: return "IV_CHUNK";
    case HEADER_REJECT_SESSION_LIMIT: return "SESSION_LIMIT";
    default: return "UNKNOWN";
    }
}

static int iv_is_zero(const u32 iv_words[3])
{
    return (iv_words[0] | iv_words[1] | iv_words[2]) == 0U;
}

static int nonce_was_accepted(const u32 iv_words[3])
{
    u32 index;
    for(index = 0U; index < accepted_nonce_count; ++index)
        if(accepted_nonces[index][0] == iv_words[0] &&
           accepted_nonces[index][1] == iv_words[1])
            return 1;
    return 0;
}

static void commit_freshness_state(void)
{
    if(chunk_index == 0U)
    {
        accepted_nonces[accepted_nonce_count][0] = initial_iv[0];
        accepted_nonces[accepted_nonce_count][1] = initial_iv[1];
        ++accepted_nonce_count;
        image_active = 1;
        active_sequence = packet_sequence;
        active_total_chunks = total_chunks;
        active_width = image_width;
        active_height = image_height;
        active_nonce[0] = initial_iv[0];
        active_nonce[1] = initial_iv[1];
    }
    ++accepted_chunk_count;
    if(chunk_index + 1U == total_chunks)
    {
        last_completed_sequence = packet_sequence;
        expected_chunk_index = 0U;
        image_active = 0;
    }
    else
        expected_chunk_index = chunk_index + 1U;
}

static header_result_t receive_and_validate_header(void)
{
    static const u8 expected_magic[4] = {'C', 'H', 'K', '3'};
    static const u8 stop_magic[4] = {'E', 'N', 'D', '3'};
    u8 header[HEADER_SIZE_BYTES];
    const u8 *aad;
    const u8 *iv;
    u32 candidate_aad[4];
    u32 candidate_iv[3];
    u32 candidate_width;
    u32 candidate_height;
    u32 candidate_sequence;
    u32 candidate_chunk_index;
    u32 candidate_total_chunks;
    u32 declared_size;
    u64 expected_size;
    u32 expected_total_chunks;
    u32 expected_chunk_bytes;
    u32 index;

    receive_exact(header, HEADER_SIZE_BYTES);
    if(header[0] == stop_magic[0] && header[1] == stop_magic[1] &&
       header[2] == stop_magic[2] && header[3] == stop_magic[3])
    {
        for(index = 4U; index < HEADER_SIZE_BYTES; ++index)
            if(header[index] != 0U)
                return HEADER_REJECT_MAGIC;
        return HEADER_STOP_REQUEST;
    }
    for(index = 0U; index < 4U; ++index)
        if(header[index] != expected_magic[index])
            return HEADER_REJECT_MAGIC;

    aad = &header[4];
    iv = &header[20];
    if(aad[0] != PROTOCOL_VERSION)
        return HEADER_REJECT_VERSION;
    if(aad[1] != FORMAT_RGB888)
        return HEADER_REJECT_FORMAT;
    if(aad[2] != RGB_CHANNELS)
        return HEADER_REJECT_CHANNELS;
    if((aad[3] & 0xFEU) != 0U)
        return HEADER_REJECT_FLAGS;

    candidate_width = unpack_be16(&aad[4]);
    candidate_height = unpack_be16(&aad[6]);
    declared_size = unpack_be16(&aad[8]);
    candidate_chunk_index = unpack_be16(&aad[10]);
    candidate_total_chunks = unpack_be16(&aad[12]);
    candidate_sequence = unpack_be16(&aad[14]);

    if(candidate_width == 0U || candidate_height == 0U ||
       candidate_width > MAX_IMAGE_WIDTH ||
       candidate_height > MAX_IMAGE_HEIGHT)
        return HEADER_REJECT_DIMENSIONS;

    expected_size = (u64)candidate_width * (u64)candidate_height *
                    (u64)RGB_CHANNELS;
    if(expected_size > (u64)MAX_IMAGE_BYTES)
        return HEADER_REJECT_PAYLOAD_SIZE;
    expected_total_chunks = ((u32)expected_size +
                             PROTECTED_CHUNK_BYTES - 1U) /
                            PROTECTED_CHUNK_BYTES;
    if(candidate_total_chunks != expected_total_chunks ||
       candidate_chunk_index >= candidate_total_chunks)
        return HEADER_REJECT_CHUNK_COUNT;
    expected_chunk_bytes = (candidate_chunk_index + 1U ==
                            candidate_total_chunks) ?
                           ((u32)expected_size -
                            candidate_chunk_index * PROTECTED_CHUNK_BYTES) :
                           PROTECTED_CHUNK_BYTES;
    if(declared_size == 0U || declared_size > PROTECTED_CHUNK_BYTES ||
       declared_size != expected_chunk_bytes)
        return HEADER_REJECT_PAYLOAD_SIZE;
    if((aad[3] & 1U) !=
       (candidate_chunk_index + 1U == candidate_total_chunks ? 1U : 0U))
        return HEADER_REJECT_FLAGS;
    if(candidate_sequence == 0U)
        return HEADER_REJECT_SEQUENCE_ZERO;

    for(index = 0U; index < 4U; ++index)
        candidate_aad[index] = pack_be32(&aad[index * 4U]);
    for(index = 0U; index < 3U; ++index)
        candidate_iv[index] = pack_be32(&iv[index * 4U]);
    if(iv_is_zero(candidate_iv))
        return HEADER_REJECT_IV_ZERO;
    if(candidate_iv[2] != candidate_chunk_index)
        return HEADER_REJECT_IV_CHUNK;
    if(accepted_chunk_count >= MAX_SESSION_TRANSACTIONS)
        return HEADER_REJECT_SESSION_LIMIT;

    if(candidate_chunk_index == 0U)
    {
        if(image_active)
            return HEADER_REJECT_CHUNK_ORDER;
        if(candidate_sequence <= last_completed_sequence)
            return HEADER_REJECT_SEQUENCE_REPLAY;
        if(nonce_was_accepted(candidate_iv))
            return HEADER_REJECT_IV_REUSE;
        if(accepted_nonce_count >= MAX_SESSION_IMAGES)
            return HEADER_REJECT_SESSION_LIMIT;
    }
    else
    {
        if(!image_active || candidate_chunk_index != expected_chunk_index ||
           candidate_sequence != active_sequence ||
           candidate_total_chunks != active_total_chunks ||
           candidate_width != active_width || candidate_height != active_height)
            return HEADER_REJECT_CHUNK_ORDER;
        if(candidate_iv[0] != active_nonce[0] ||
           candidate_iv[1] != active_nonce[1])
            return HEADER_REJECT_IV_REUSE;
    }

    image_width = candidate_width;
    image_height = candidate_height;
    image_size_bytes = declared_size;
    packet_sequence = candidate_sequence;
    chunk_index = candidate_chunk_index;
    total_chunks = candidate_total_chunks;
    for(index = 0U; index < 4U; ++index)
        aad_words[index] = candidate_aad[index];
    for(index = 0U; index < 3U; ++index)
        initial_iv[index] = candidate_iv[index];
    return HEADER_ACCEPTED;
}

static int initialize_dma(void)
{
    XAxiDma_Config *config;
#ifdef SDT
    config = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
#else
    config = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
#endif
    if(config == NULL)
        return XST_FAILURE;
    if(XAxiDma_CfgInitialize(&axi_dma, config) != XST_SUCCESS)
        return XST_FAILURE;
    if(XAxiDma_HasSg(&axi_dma))
        return XST_FAILURE;
    XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DEVICE_TO_DMA);
    return XST_SUCCESS;
}

static int poll_status(u32 mask, u32 expected)
{
    u32 timeout = GCM_TIMEOUT;
    while(timeout != 0U)
    {
        if((Xil_In32(GCM_BASE + REG_STATUS) & mask) == expected)
            return XST_SUCCESS;
        --timeout;
    }
    return XST_FAILURE;
}

static int prepare_gcm(u32 mode, const u32 expected_tag[4])
{
    u32 index;

    Xil_Out32(GCM_BASE + REG_CONTROL, CTRL_SOFT_RESET);
    Xil_Out32(GCM_BASE + REG_MODE, mode);
    for(index = 0U; index < 4U; ++index)
        Xil_Out32(GCM_BASE + REG_KEY0 + index * 4U, aes_key[index]);
    for(index = 0U; index < 3U; ++index)
        Xil_Out32(GCM_BASE + REG_IV0 + index * 4U, initial_iv[index]);
    for(index = 0U; index < 4U; ++index)
    {
        Xil_Out32(GCM_BASE + REG_EXPECTED_TAG0 + index * 4U,
                  expected_tag == NULL ? 0U : expected_tag[index]);
        Xil_Out32(GCM_BASE + REG_AAD0 + index * 4U, aad_words[index]);
    }
    Xil_Out32(GCM_BASE + REG_AAD_BYTES, AAD_SIZE_BYTES);

    Xil_Out32(GCM_BASE + REG_CONTROL, CTRL_LOAD_IV);
    if(poll_status(STATUS_GCM_READY, STATUS_GCM_READY) != XST_SUCCESS)
        return XST_FAILURE;
    Xil_Out32(GCM_BASE + REG_CONTROL, CTRL_ENABLE | CTRL_CLEAR_DONE);
    return XST_SUCCESS;
}

static int wait_for_dma(void)
{
    u32 timeout = DMA_TIMEOUT;
    while((XAxiDma_Busy(&axi_dma, XAXIDMA_DMA_TO_DEVICE) ||
           XAxiDma_Busy(&axi_dma, XAXIDMA_DEVICE_TO_DMA)) && timeout != 0U)
        --timeout;
    if(timeout == 0U)
    {
        XAxiDma_Reset(&axi_dma);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

static int poll_buffer_status(u32 mask, u32 expected)
{
    u32 timeout = DMA_TIMEOUT;
    while(timeout != 0U)
    {
        if((Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_STATUS) & mask) ==
           expected)
            return XST_SUCCESS;
        --timeout;
    }
    return XST_FAILURE;
}

static int protected_buffer_zeroize(void)
{
    Xil_Out32(PROTECTED_BUFFER_BASE + BUFFER_REG_CONTROL,
              BUFFER_CTRL_ZEROIZE);
    return poll_buffer_status(BUFFER_STATUS_IDLE |
                              BUFFER_STATUS_ZEROIZE_DONE,
                              BUFFER_STATUS_IDLE |
                              BUFFER_STATUS_ZEROIZE_DONE);
}

static int protected_buffer_capture(u8 *input, u32 size)
{
    int status;
    u32 final_status;

    if(size == 0U || size > PROTECTED_CHUNK_BYTES)
        return XST_FAILURE;
    if(poll_buffer_status(BUFFER_STATUS_IDLE, BUFFER_STATUS_IDLE) !=
       XST_SUCCESS)
        return XST_FAILURE;

    Xil_Out32(PROTECTED_BUFFER_BASE + BUFFER_REG_CONTROL, BUFFER_CTRL_CLEAR);
    Xil_Out32(PROTECTED_BUFFER_BASE + BUFFER_REG_EXPECT_BYTES, size);
    Xil_Out32(PROTECTED_BUFFER_BASE + BUFFER_REG_CONTROL, BUFFER_CTRL_CAPTURE);
    Xil_DCacheFlushRange((INTPTR)input, size);
    status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)input, size,
                                    XAXIDMA_DMA_TO_DEVICE);
    if(status != XST_SUCCESS || wait_for_dma() != XST_SUCCESS)
        return XST_FAILURE;
    if(poll_buffer_status(BUFFER_STATUS_LOCKED |
                          BUFFER_STATUS_CAPTURE_DONE,
                          BUFFER_STATUS_LOCKED |
                          BUFFER_STATUS_CAPTURE_DONE) != XST_SUCCESS)
        return XST_FAILURE;

    final_status = Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_STATUS);
    if((final_status & (BUFFER_STATUS_OVERFLOW |
                        BUFFER_STATUS_LENGTH_ERROR)) != 0U ||
       Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_CAPTURED) != size)
        return XST_FAILURE;
    return XST_SUCCESS;
}

static int protected_buffer_replay(void)
{
    u32 before = Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_REPLAYS);
    Xil_Out32(PROTECTED_BUFFER_BASE + BUFFER_REG_CONTROL, BUFFER_CTRL_REPLAY);
    if(poll_buffer_status(BUFFER_STATUS_REPLAY_DONE,
                          BUFFER_STATUS_REPLAY_DONE) != XST_SUCCESS)
        return XST_FAILURE;
    if(Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_REPLAYS) != before + 1U)
        return XST_FAILURE;
    return XST_SUCCESS;
}

static int dma_process_gcm(u8 *input, u8 *output, u32 size, u32 mode,
                           const u32 expected_tag[4], u32 generated_tag[4],
                           u32 *final_status)
{
    int status;
    u32 index;
    u32 expected_blocks = (size + 15U) / 16U;

    if(size == 0U || size > PROTECTED_CHUNK_BYTES)
        return XST_FAILURE;

    /*
     * Encrypt and auth-only operations capture their source once. A release
     * pass deliberately does not recapture: it replays the immutable copy
     * that was authenticated immediately before this call.
     */
    if(mode != MODE_DECRYPT &&
       protected_buffer_capture(input, size) != XST_SUCCESS)
        return XST_FAILURE;
    if(mode == MODE_DECRYPT &&
       poll_buffer_status(BUFFER_STATUS_LOCKED,
                          BUFFER_STATUS_LOCKED) != XST_SUCCESS)
        return XST_FAILURE;
    if(prepare_gcm(mode, expected_tag) != XST_SUCCESS)
        return XST_FAILURE;

    Xil_DCacheFlushRange((INTPTR)input, size);
    if(output != NULL)
        Xil_DCacheFlushRange((INTPTR)output, size);

    /*
     * Authentication-only mode deliberately does not arm S2MM. Therefore no
     * plaintext destination exists while the tag is being checked.
     */
    if(mode != MODE_AUTH_ONLY)
    {
        if(output == NULL)
            return XST_FAILURE;
        status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)output, size,
                                        XAXIDMA_DEVICE_TO_DMA);
        if(status != XST_SUCCESS)
            return XST_FAILURE;
    }
    if(protected_buffer_replay() != XST_SUCCESS ||
       wait_for_dma() != XST_SUCCESS)
        return XST_FAILURE;
    if(poll_status(STATUS_DONE | STATUS_TAG_VALID,
                   STATUS_DONE | STATUS_TAG_VALID) != XST_SUCCESS)
        return XST_FAILURE;

    if(output != NULL)
        Xil_DCacheInvalidateRange((INTPTR)output, size);
    *final_status = Xil_In32(GCM_BASE + REG_STATUS);
    if(Xil_In32(GCM_BASE + REG_BLOCKS) != expected_blocks ||
       Xil_In32(GCM_BASE + REG_BYTES) != size)
        return XST_FAILURE;
    for(index = 0U; index < 4U; ++index)
        generated_tag[index] = Xil_In32(GCM_BASE + REG_TAG0 + index * 4U);

    Xil_Out32(GCM_BASE + REG_CONTROL, 0U);

    /* Encryption and completed release do not retain their protected copy. */
    if((mode == MODE_ENCRYPT || mode == MODE_DECRYPT) &&
       protected_buffer_zeroize() != XST_SUCCESS)
        return XST_FAILURE;
    return XST_SUCCESS;
}

static int compare_buffers(const u8 *left, const u8 *right, u32 size)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        if(left[index] != right[index])
            return (int)index + 1;
    return 0;
}

static void zeroize_buffer(u8 *buffer, u32 size)
{
    volatile u8 *target = (volatile u8 *)buffer;
    u32 index;
    for(index = 0U; index < size; ++index)
        target[index] = 0U;
    Xil_DCacheFlushRange((INTPTR)buffer, size);
}

static void fill_buffer(u8 *buffer, u32 size, u8 value)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        buffer[index] = value;
    Xil_DCacheFlushRange((INTPTR)buffer, size);
}

static int buffer_is_value(const u8 *buffer, u32 size, u8 value)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        if(buffer[index] != value)
            return 0;
    return 1;
}

static int buffer_is_zero(const u8 *buffer, u32 size)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        if(buffer[index] != 0U)
            return 0;
    return 1;
}

static void send_bytes(const u8 *data, u32 size)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        outbyte((char)data[index]);
}

static void print_performance(const char *operation, u64 start, u64 end,
                              u32 size)
{
    u64 ticks = end - start;
    u64 frequency = read_arm_counter_frequency();
    u64 nanoseconds;
    u64 microseconds;
    u64 throughput_kbps;

    if(frequency == 0U)
        frequency = 1U;
    nanoseconds = (ticks * 1000000000ULL) / frequency;
    if(nanoseconds == 0U)
        nanoseconds = 1U;
    microseconds = nanoseconds / 1000ULL;
    if(microseconds == 0U)
        microseconds = 1U;
    throughput_kbps = ((u64)size * 1000000ULL) / nanoseconds;

    xil_printf("%s_COUNTER_TICKS %u\r\n", operation, (unsigned int)ticks);
    xil_printf("%s_TIME_NS %u\r\n", operation,
               (unsigned int)nanoseconds);
    xil_printf("%s_TIME_US %u\r\n", operation,
               (unsigned int)microseconds);
    xil_printf("%s_THROUGHPUT_KBPS %u\r\n", operation,
               (unsigned int)throughput_kbps);
}

static void print_tag(const char *prefix, const u32 tag[4])
{
    xil_printf("%s %08x%08x%08x%08x\r\n", prefix,
               (unsigned int)tag[0], (unsigned int)tag[1],
               (unsigned int)tag[2], (unsigned int)tag[3]);
}

static int process_transaction(void)
{
    u64 start_count;
    u64 end_count;
    u64 auth_only_ticks;
    u64 release_decrypt_ticks;
    u32 encryption_tag[4];
    u32 check_tag[4];
    u32 final_status;
    u32 tamper_index;
    u8 original_cipher_byte;
    int mismatch;

    xil_printf("ENCRYPTING_GCM_DMA\r\n");
    start_count = read_arm_counter();
    if(dma_process_gcm(input_image, encrypted_image, image_size_bytes,
                       MODE_ENCRYPT, NULL, encryption_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_ENCRYPT\r\n");
        return 3;
    }
    end_count = read_arm_counter();
    print_performance("ENCRYPTION_GCM_DMA", start_count, end_count,
                      image_size_bytes);
    print_tag("GCM_TAG", encryption_tag);

    /* Pass 1: authenticate ciphertext while the RTL output is suppressed. */
    xil_printf("AUTHENTICATING_BEFORE_RELEASE\r\n");
    xil_printf("AUTH_ONLY_S2MM_ARMED NO\r\n");
    fill_buffer(recovered_image, image_size_bytes, 0xA5U);
    start_count = read_arm_counter();
    if(dma_process_gcm(encrypted_image, recovered_image, image_size_bytes,
                       MODE_AUTH_ONLY, encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_AUTH_ONLY\r\n");
        return 4;
    }
    end_count = read_arm_counter();
    auth_only_ticks = end_count - start_count;
    print_performance("AUTH_ONLY_GCM_DMA", start_count, end_count,
                      image_size_bytes);
    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL |
                        STATUS_OUTPUT_SUPPRESSED)) !=
       (STATUS_TAG_MATCH | STATUS_OUTPUT_SUPPRESSED))
    {
        xil_printf("ERROR AUTH_ONLY_REJECTED_VALID_CIPHERTEXT\r\n");
        return 5;
    }
    if(!buffer_is_value(recovered_image, image_size_bytes, 0xA5U))
    {
        xil_printf("ERROR AUTH_ONLY_PROBE_CHANGED\r\n");
        return 6;
    }
    xil_printf("AUTH_ONLY_VALID_TAG_PASS\r\n");
    xil_printf("AUTH_ONLY_OUTPUT_SUPPRESSED PASS\r\n");
    xil_printf("AUTH_ONLY_PROBE_UNCHANGED PASS\r\n");

    if((Xil_In32(PROTECTED_BUFFER_BASE + BUFFER_REG_STATUS) &
        BUFFER_STATUS_LOCKED) == 0U)
    {
        xil_printf("ERROR PROTECTED_BUFFER_UNLOCKED_BEFORE_RELEASE\r\n");
        return 20;
    }
    xil_printf("PROTECTED_BUFFER_LOCKED_BETWEEN_PASSES PASS\r\n");

    /*
     * Pass 2 is allowed only after Pass 1 succeeds. The ciphertext buffer is
     * owned by this transaction and is not modified between the two passes.
     */
    xil_printf("DECRYPTION_RELEASE_ALLOWED\r\n");
    xil_printf("DECRYPTING_AUTHENTICATED_GCM_DMA\r\n");
    start_count = read_arm_counter();
    if(dma_process_gcm(encrypted_image, recovered_image, image_size_bytes,
                       MODE_DECRYPT, encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_DECRYPT_RELEASE\r\n");
        return 7;
    }
    end_count = read_arm_counter();
    release_decrypt_ticks = end_count - start_count;
    print_performance("DECRYPTION_RELEASE_GCM_DMA", start_count, end_count,
                      image_size_bytes);
    print_performance("AUTHENTICATE_THEN_RELEASE_GCM_DMA",
                      0U, auth_only_ticks + release_decrypt_ticks,
                      image_size_bytes);
    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL)) !=
       STATUS_TAG_MATCH)
    {
        xil_printf("ERROR SECOND_PASS_TAG_CHECK_FAILED\r\n");
        return 8;
    }
    mismatch = compare_buffers(input_image, recovered_image, image_size_bytes);
    if(mismatch != 0)
    {
        xil_printf("ERROR RECOVERY_MISMATCH_AT_%d\r\n", mismatch - 1);
        return 9;
    }
    xil_printf("AUTHENTICATION_PASS\r\n");
    xil_printf("RECOVERY_PASS\r\n");
    xil_printf("PROTECTED_BUFFER_REPLAYED_WITHOUT_RECAPTURE PASS\r\n");

    xil_printf("CIPHERTEXT_BEGIN %u\r\n", (unsigned int)image_size_bytes);
    send_bytes(encrypted_image, image_size_bytes);
    xil_printf("\r\nCIPHERTEXT_END\r\n");
    xil_printf("RECOVERED_BEGIN %u\r\n", (unsigned int)image_size_bytes);
    send_bytes(recovered_image, image_size_bytes);
    xil_printf("\r\nRECOVERED_END\r\n");

    tamper_index = image_size_bytes / 2U;
    original_cipher_byte = encrypted_image[tamper_index];
    encrypted_image[tamper_index] ^= (u8)TAMPER_XOR_MASK;
    xil_printf("TAMPER_BYTE_INDEX %u\r\n", (unsigned int)tamper_index);
    xil_printf("AUTHENTICATING_TAMPERED_CIPHERTEXT_BEFORE_RELEASE\r\n");
    xil_printf("TAMPER_AUTH_ONLY_S2MM_ARMED NO\r\n");
    fill_buffer(recovered_image, image_size_bytes, 0xC3U);
    if(dma_process_gcm(encrypted_image, recovered_image, image_size_bytes,
                       MODE_AUTH_ONLY, encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_CIPHERTEXT_TAMPER_AUTH_ONLY\r\n");
        return 10;
    }
    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL |
                        STATUS_OUTPUT_SUPPRESSED)) !=
       (STATUS_AUTH_FAIL | STATUS_OUTPUT_SUPPRESSED))
    {
        xil_printf("ERROR CIPHERTEXT_TAMPER_NOT_REJECTED\r\n");
        return 11;
    }
    if(!buffer_is_value(recovered_image, image_size_bytes, 0xC3U))
    {
        xil_printf("ERROR TAMPER_AUTH_ONLY_PROBE_CHANGED\r\n");
        return 12;
    }
    xil_printf("TAMPER_REJECTED_BEFORE_DECRYPT PASS\r\n");
    xil_printf("TAMPER_DECRYPTION_STARTED NO\r\n");
    xil_printf("TAMPER_PLAINTEXT_DMA_ARMED NO\r\n");
    xil_printf("TAMPER_AUTH_ONLY_PROBE_UNCHANGED PASS\r\n");
    xil_printf("CIPHERTEXT_TAMPER_REJECTED PASS\r\n");
    xil_printf("PLAINTEXT_RELEASED NO\r\n");
    zeroize_buffer(recovered_image, image_size_bytes);
    if(!buffer_is_zero(recovered_image, image_size_bytes))
    {
        xil_printf("ERROR ZEROIZATION_FAILED\r\n");
        return 13;
    }
    xil_printf("TAMPERED_BUFFER_ZEROIZED\r\n");
    if(protected_buffer_zeroize() != XST_SUCCESS)
    {
        xil_printf("ERROR PROTECTED_TAMPER_BUFFER_ZEROIZATION_FAILED\r\n");
        return 18;
    }
    xil_printf("PROTECTED_TAMPER_BUFFER_ZEROIZED\r\n");
    xil_printf("REJECTED_BUFFER_BEGIN %u\r\n",
               (unsigned int)image_size_bytes);
    send_bytes(recovered_image, image_size_bytes);
    xil_printf("\r\nREJECTED_BUFFER_END\r\n");
    encrypted_image[tamper_index] = original_cipher_byte;

    /* Change only the authenticated sequence field, not the ciphertext. */
    aad_words[3] ^= 0x00000001U;
    xil_printf("AUTHENTICATING_TAMPERED_AAD_BEFORE_RELEASE\r\n");
    xil_printf("AAD_TAMPER_AUTH_ONLY_S2MM_ARMED NO\r\n");
    fill_buffer(recovered_image, image_size_bytes, 0x3CU);
    if(dma_process_gcm(encrypted_image, recovered_image, image_size_bytes,
                       MODE_AUTH_ONLY, encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_AAD_TAMPER_AUTH_ONLY\r\n");
        return 14;
    }
    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL |
                        STATUS_OUTPUT_SUPPRESSED)) !=
       (STATUS_AUTH_FAIL | STATUS_OUTPUT_SUPPRESSED))
    {
        xil_printf("ERROR AAD_TAMPER_NOT_REJECTED\r\n");
        return 15;
    }
    if(!buffer_is_value(recovered_image, image_size_bytes, 0x3CU))
    {
        xil_printf("ERROR AAD_TAMPER_AUTH_ONLY_PROBE_CHANGED\r\n");
        return 16;
    }
    xil_printf("AAD_TAMPER_REJECTED_BEFORE_DECRYPT PASS\r\n");
    xil_printf("AAD_TAMPER_DECRYPTION_STARTED NO\r\n");
    xil_printf("AAD_TAMPER_PLAINTEXT_DMA_ARMED NO\r\n");
    xil_printf("AAD_TAMPER_AUTH_ONLY_PROBE_UNCHANGED PASS\r\n");
    xil_printf("AAD_TAMPER_REJECTED PASS\r\n");
    xil_printf("AAD_TAMPER_PLAINTEXT_RELEASED NO\r\n");
    zeroize_buffer(recovered_image, image_size_bytes);
    if(!buffer_is_zero(recovered_image, image_size_bytes))
    {
        xil_printf("ERROR AAD_TAMPER_ZEROIZATION_FAILED\r\n");
        return 17;
    }
    xil_printf("AAD_TAMPERED_BUFFER_ZEROIZED\r\n");
    if(protected_buffer_zeroize() != XST_SUCCESS)
    {
        xil_printf("ERROR PROTECTED_AAD_BUFFER_ZEROIZATION_FAILED\r\n");
        return 19;
    }
    xil_printf("PROTECTED_AAD_BUFFER_ZEROIZED\r\n");
    aad_words[3] ^= 0x00000001U;

    xil_printf("ZCU104_AES_GCM_TRANSACTION_DONE\r\n");
    return 0;
}

int main(void)
{
    header_result_t header_result;
    int transaction_status;

    init_platform();
    xil_printf("\r\nZCU104_AES_GCM_PROTECTED_CHUNK_START\r\n");
    xil_printf("MAX_IMAGE_FORMAT %u %u RGB888 %u\r\n",
               (unsigned int)MAX_IMAGE_WIDTH,
               (unsigned int)MAX_IMAGE_HEIGHT,
               (unsigned int)MAX_IMAGE_BYTES);
    xil_printf("MAX_SESSION_TRANSACTIONS %u\r\n",
               (unsigned int)MAX_SESSION_TRANSACTIONS);
    xil_printf("PROTECTED_CHUNK_BYTES %u\r\n",
               (unsigned int)PROTECTED_CHUNK_BYTES);
    xil_printf("CIPHERTEXT_STORAGE ON_CHIP_LOCKED_BRAM\r\n");
    xil_printf("REPLAY_SCOPE VOLATILE_SESSION_ONLY\r\n");
    xil_printf("PLAINTEXT_RELEASE_POLICY AUTHENTICATE_THEN_RELEASE\r\n");
    xil_printf("AUTH_ONLY_OUTPUT_PATH DISABLED\r\n");
    xil_printf("ARM_COUNTER_FREQUENCY_HZ %u\r\n",
               (unsigned int)read_arm_counter_frequency());

    if(initialize_dma() != XST_SUCCESS)
    {
        xil_printf("ERROR DMA_INITIALIZATION\r\n");
        cleanup_platform();
        return 1;
    }

    while(1)
    {
        xil_printf("READY_FOR_HEADER %u ACCEPTED %u\r\n",
                   (unsigned int)HEADER_SIZE_BYTES,
                   (unsigned int)accepted_chunk_count);
        header_result = receive_and_validate_header();
        if(header_result == HEADER_STOP_REQUEST)
        {
            xil_printf("SESSION_STOP_ACCEPTED\r\n");
            break;
        }
        if(header_result != HEADER_ACCEPTED)
        {
            xil_printf("HEADER_REJECTED %s\r\n",
                       header_result_name(header_result));
            continue;
        }

        xil_printf("HEADER_ACCEPTED WIDTH %u HEIGHT %u CHUNK_BYTES %u "
                   "CHUNK %u TOTAL_CHUNKS %u SEQUENCE %u\r\n",
                   (unsigned int)image_width, (unsigned int)image_height,
                   (unsigned int)image_size_bytes,
                   (unsigned int)chunk_index,
                   (unsigned int)total_chunks,
                   (unsigned int)packet_sequence);
        xil_printf("IV %08x%08x%08x\r\n", (unsigned int)initial_iv[0],
                   (unsigned int)initial_iv[1],
                   (unsigned int)initial_iv[2]);
        xil_printf("AAD %08x%08x%08x%08x\r\n",
                   (unsigned int)aad_words[0],
                   (unsigned int)aad_words[1],
                   (unsigned int)aad_words[2],
                   (unsigned int)aad_words[3]);
        xil_printf("READY_FOR_PAYLOAD %u\r\n",
                   (unsigned int)image_size_bytes);
        receive_exact(input_image, image_size_bytes);
        xil_printf("IMAGE_RECEIVED %u\r\n",
                   (unsigned int)image_size_bytes);

        transaction_status = process_transaction();
        if(transaction_status != 0)
        {
            xil_printf("SESSION_ABORTED TRANSACTION_ERROR %d\r\n",
                       transaction_status);
            cleanup_platform();
            return transaction_status;
        }

        commit_freshness_state();
        zeroize_buffer(input_image, image_size_bytes);
        zeroize_buffer(encrypted_image, image_size_bytes);
        zeroize_buffer(recovered_image, image_size_bytes);
        if(!buffer_is_zero(input_image, image_size_bytes) ||
           !buffer_is_zero(encrypted_image, image_size_bytes) ||
           !buffer_is_zero(recovered_image, image_size_bytes))
        {
            xil_printf("ERROR TRANSACTION_BUFFER_ZEROIZATION_FAILED\r\n");
            cleanup_platform();
            return 13;
        }
        xil_printf("TRANSACTION_BUFFERS_ZEROIZED\r\n");
        xil_printf("CHUNK_COMMITTED SEQUENCE %u CHUNK %u ACCEPTED %u\r\n",
                   (unsigned int)packet_sequence,
                   (unsigned int)chunk_index,
                   (unsigned int)accepted_chunk_count);
    }

    xil_printf("ZCU104_AES_GCM_PROTECTED_CHUNK_DONE ACCEPTED %u\r\n",
               (unsigned int)accepted_chunk_count);
    cleanup_platform();
    return 0;
}
