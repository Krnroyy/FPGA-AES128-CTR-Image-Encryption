#include "platform.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"

#define GCM_BASE          0xA0000000U
#define REG_CONTROL       0x00U
#define REG_STATUS        0x04U
#define REG_BLOCKS        0x08U
#define REG_MODE          0x0CU
#define REG_KEY0          0x10U
#define REG_IV0           0x20U
#define REG_TAG0          0x30U
#define REG_EXPECTED_TAG0 0x40U
#define REG_BYTES         0x50U

#define CTRL_ENABLE       0x01U
#define CTRL_LOAD_IV      0x02U
#define CTRL_SOFT_RESET   0x04U
#define CTRL_CLEAR_DONE   0x08U

#define STATUS_DONE       0x02U
#define STATUS_GCM_READY  0x10U
#define STATUS_TAG_VALID  0x20U
#define STATUS_TAG_MATCH  0x40U
#define STATUS_AUTH_FAIL  0x80U

#define MODE_ENCRYPT      0U
#define MODE_DECRYPT      1U

#define IMAGE_WIDTH       256U
#define IMAGE_HEIGHT      256U
#define IMAGE_CHANNELS    3U
#define IMAGE_SIZE_BYTES  (IMAGE_WIDTH * IMAGE_HEIGHT * IMAGE_CHANNELS)
#define IMAGE_BLOCKS      (IMAGE_SIZE_BYTES / 16U)
#define PACKET_SIZE_BYTES (IMAGE_SIZE_BYTES + 16U)
#define DMA_TIMEOUT       200000000U
#define GCM_TIMEOUT       200000000U

#define TAMPER_BYTE_INDEX 98688U
#define TAMPER_XOR_MASK   0x01U

static u8 input_image[IMAGE_SIZE_BYTES] __attribute__((aligned(64)));
static u8 encrypted_image[IMAGE_SIZE_BYTES] __attribute__((aligned(64)));
static u8 recovered_image[IMAGE_SIZE_BYTES] __attribute__((aligned(64)));

static const u32 aes_key[4] = {
    0x2B7E1516U, 0x28AED2A6U, 0xABF71588U, 0x09CF4F3CU
};
static u32 initial_iv[3];
static XAxiDma axi_dma;

extern char inbyte(void);
extern void outbyte(char c);

static inline u64 read_arm_counter(void)
{
    u64 value;
    __asm__ volatile("isb" ::: "memory");
    __asm__ volatile("mrs %0, cntpct_el0" : "=r" (value));
    return value;
}

static inline u64 read_arm_counter_frequency(void)
{
    u64 value;
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r" (value));
    return value;
}

static u32 pack_be32(const u8 *bytes)
{
    return ((u32)bytes[0] << 24) | ((u32)bytes[1] << 16) |
           ((u32)bytes[2] << 8) | (u32)bytes[3];
}

static void receive_exact(u8 *destination, u32 size)
{
    u32 index;
    for(index = 0U; index < size; ++index)
        destination[index] = (u8)inbyte();
}

static int receive_image_packet(void)
{
    static const u8 expected_magic[4] = {'G', 'C', 'M', '1'};
    u8 magic[4];
    u8 iv_bytes[12];
    u32 index;

    receive_exact(magic, 4U);
    for(index = 0U; index < 4U; ++index)
        if(magic[index] != expected_magic[index])
            return XST_FAILURE;

    receive_exact(iv_bytes, 12U);
    for(index = 0U; index < 3U; ++index)
        initial_iv[index] = pack_be32(&iv_bytes[index * 4U]);
    receive_exact(input_image, IMAGE_SIZE_BYTES);
    return XST_SUCCESS;
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
        Xil_Out32(GCM_BASE + REG_EXPECTED_TAG0 + index * 4U,
                  expected_tag == NULL ? 0U : expected_tag[index]);

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

static int dma_process_gcm(u8 *input, u8 *output, u32 mode,
                           const u32 expected_tag[4], u32 generated_tag[4],
                           u32 *final_status)
{
    int status;
    u32 index;

    if(prepare_gcm(mode, expected_tag) != XST_SUCCESS)
        return XST_FAILURE;

    Xil_DCacheFlushRange((INTPTR)input, IMAGE_SIZE_BYTES);
    Xil_DCacheFlushRange((INTPTR)output, IMAGE_SIZE_BYTES);

    status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)output,
                                    IMAGE_SIZE_BYTES,
                                    XAXIDMA_DEVICE_TO_DMA);
    if(status != XST_SUCCESS)
        return XST_FAILURE;
    status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)input,
                                    IMAGE_SIZE_BYTES,
                                    XAXIDMA_DMA_TO_DEVICE);
    if(status != XST_SUCCESS)
    {
        XAxiDma_Reset(&axi_dma);
        return XST_FAILURE;
    }
    if(wait_for_dma() != XST_SUCCESS)
        return XST_FAILURE;
    if(poll_status(STATUS_DONE | STATUS_TAG_VALID,
                   STATUS_DONE | STATUS_TAG_VALID) != XST_SUCCESS)
        return XST_FAILURE;

    Xil_DCacheInvalidateRange((INTPTR)output, IMAGE_SIZE_BYTES);
    *final_status = Xil_In32(GCM_BASE + REG_STATUS);
    if(Xil_In32(GCM_BASE + REG_BLOCKS) != IMAGE_BLOCKS ||
       Xil_In32(GCM_BASE + REG_BYTES) != IMAGE_SIZE_BYTES)
        return XST_FAILURE;
    for(index = 0U; index < 4U; ++index)
        generated_tag[index] = Xil_In32(GCM_BASE + REG_TAG0 + index * 4U);

    Xil_Out32(GCM_BASE + REG_CONTROL, 0U);
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

static void print_performance(const char *operation, u64 start, u64 end)
{
    u64 ticks = end - start;
    u64 frequency = read_arm_counter_frequency();
    u64 nanoseconds;
    u64 microseconds;
    u64 throughput_kbps;

    if(frequency == 0U)
        frequency = 1U;
    nanoseconds = (ticks * 1000000000ULL) / frequency;
    microseconds = nanoseconds / 1000ULL;
    if(microseconds == 0U)
        microseconds = 1U;
    throughput_kbps = ((u64)IMAGE_SIZE_BYTES * 1000ULL) / microseconds;

    xil_printf("%s_COUNTER_TICKS %u\r\n", operation,
               (unsigned int)ticks);
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

int main(void)
{
    u64 start_count;
    u64 end_count;
    u64 counter_frequency;
    u32 encryption_tag[4];
    u32 check_tag[4];
    u32 final_status;
    u8 original_cipher_byte;
    int mismatch;

    init_platform();
    xil_printf("\r\nZCU104_AES_GCM_DMA_START\r\n");
    xil_printf("IMAGE_FORMAT 256 256 RGB888 %u\r\n",
               (unsigned int)IMAGE_SIZE_BYTES);
    counter_frequency = read_arm_counter_frequency();
    xil_printf("ARM_COUNTER_FREQUENCY_HZ %u\r\n",
               (unsigned int)counter_frequency);

    if(initialize_dma() != XST_SUCCESS)
    {
        xil_printf("ERROR DMA_INITIALIZATION\r\n");
        cleanup_platform();
        return 1;
    }

    xil_printf("READY_FOR_PACKET %u\r\n", (unsigned int)PACKET_SIZE_BYTES);
    if(receive_image_packet() != XST_SUCCESS)
    {
        xil_printf("ERROR INVALID_PACKET_MAGIC\r\n");
        cleanup_platform();
        return 2;
    }
    xil_printf("IMAGE_RECEIVED %u\r\n", (unsigned int)IMAGE_SIZE_BYTES);
    xil_printf("IV %08x%08x%08x\r\n",
               (unsigned int)initial_iv[0], (unsigned int)initial_iv[1],
               (unsigned int)initial_iv[2]);

    xil_printf("ENCRYPTING_GCM_DMA\r\n");
    start_count = read_arm_counter();
    if(dma_process_gcm(input_image, encrypted_image, MODE_ENCRYPT, NULL,
                       encryption_tag, &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_ENCRYPT\r\n");
        cleanup_platform();
        return 3;
    }
    end_count = read_arm_counter();
    print_performance("ENCRYPTION_GCM_DMA", start_count, end_count);
    print_tag("GCM_TAG", encryption_tag);

    xil_printf("DECRYPTING_AUTHENTICATED_GCM_DMA\r\n");
    start_count = read_arm_counter();
    if(dma_process_gcm(encrypted_image, recovered_image, MODE_DECRYPT,
                       encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_DECRYPT\r\n");
        cleanup_platform();
        return 4;
    }
    end_count = read_arm_counter();
    print_performance("DECRYPTION_GCM_DMA", start_count, end_count);
    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL)) !=
       STATUS_TAG_MATCH)
    {
        xil_printf("ERROR AUTHENTICATION_REJECTED_VALID_CIPHERTEXT\r\n");
        cleanup_platform();
        return 5;
    }
    mismatch = compare_buffers(input_image, recovered_image,
                               IMAGE_SIZE_BYTES);
    if(mismatch != 0)
    {
        xil_printf("ERROR RECOVERY_MISMATCH_AT_%d\r\n", mismatch - 1);
        cleanup_platform();
        return 6;
    }
    xil_printf("AUTHENTICATION_PASS\r\n");
    xil_printf("RECOVERY_PASS\r\n");

    /* Release valid results only after the tag has been accepted. */
    xil_printf("CIPHERTEXT_BEGIN %u\r\n", (unsigned int)IMAGE_SIZE_BYTES);
    send_bytes(encrypted_image, IMAGE_SIZE_BYTES);
    xil_printf("\r\nCIPHERTEXT_END\r\n");
    xil_printf("RECOVERED_BEGIN %u\r\n", (unsigned int)IMAGE_SIZE_BYTES);
    send_bytes(recovered_image, IMAGE_SIZE_BYTES);
    xil_printf("\r\nRECOVERED_END\r\n");

    original_cipher_byte = encrypted_image[TAMPER_BYTE_INDEX];
    encrypted_image[TAMPER_BYTE_INDEX] ^= (u8)TAMPER_XOR_MASK;
    xil_printf("TAMPER_BYTE_INDEX %u\r\n",
               (unsigned int)TAMPER_BYTE_INDEX);
    xil_printf("TAMPER_XOR_MASK %02x\r\n",
               (unsigned int)TAMPER_XOR_MASK);
    xil_printf("CIPHERTEXT_BYTE_BEFORE %02x\r\n",
               (unsigned int)original_cipher_byte);
    xil_printf("CIPHERTEXT_BYTE_AFTER %02x\r\n",
               (unsigned int)encrypted_image[TAMPER_BYTE_INDEX]);

    xil_printf("DECRYPTING_TAMPERED_GCM_DMA\r\n");
    start_count = read_arm_counter();
    if(dma_process_gcm(encrypted_image, recovered_image, MODE_DECRYPT,
                       encryption_tag, check_tag,
                       &final_status) != XST_SUCCESS)
    {
        xil_printf("ERROR GCM_DMA_TAMPER_OPERATION\r\n");
        cleanup_platform();
        return 7;
    }
    end_count = read_arm_counter();
    print_performance("TAMPERED_DECRYPTION_GCM_DMA", start_count, end_count);

    if((final_status & (STATUS_TAG_MATCH | STATUS_AUTH_FAIL)) !=
       STATUS_AUTH_FAIL)
    {
        xil_printf("ERROR TAMPER_NOT_REJECTED\r\n");
        cleanup_platform();
        return 8;
    }
    xil_printf("AUTHENTICATION_FAIL_EXPECTED PASS\r\n");
    xil_printf("TAMPER_REJECTED\r\n");
    xil_printf("PLAINTEXT_RELEASED NO\r\n");

    /* The unauthenticated DMA result existed transiently in local DDR.
       Zeroize it before any UART transmission or application use. */
    zeroize_buffer(recovered_image, IMAGE_SIZE_BYTES);
    if(!buffer_is_zero(recovered_image, IMAGE_SIZE_BYTES))
    {
        xil_printf("ERROR ZEROIZATION_FAILED\r\n");
        cleanup_platform();
        return 9;
    }
    xil_printf("TAMPERED_BUFFER_ZEROIZED\r\n");
    xil_printf("REJECTED_BUFFER_BEGIN %u\r\n",
               (unsigned int)IMAGE_SIZE_BYTES);
    send_bytes(recovered_image, IMAGE_SIZE_BYTES);
    xil_printf("\r\nREJECTED_BUFFER_END\r\n");
    xil_printf("ZCU104_AES_GCM_DMA_DONE\r\n");

    cleanup_platform();
    return 0;
}
