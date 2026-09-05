#include "platform.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "car_256_rgb.h"

#define AES_BASE       0xA0000000U
#define REG_CONTROL    0x00U
#define REG_STATUS     0x04U
#define REG_KEY0       0x10U
#define REG_CTR0       0x20U
#define REG_DIN0       0x30U
#define REG_DOUT0      0x40U

#define CTRL_START         0x01U
#define CTRL_LOAD_COUNTER  0x02U
#define CTRL_SOFT_RESET    0x04U
#define CTRL_CLEAR_DONE    0x08U
#define STATUS_DONE        0x02U

#define POLL_TIMEOUT       1000000U
#define AES_BLOCK_BYTES    16U
#define IMAGE_BLOCKS       (IMAGE_SIZE_BYTES / AES_BLOCK_BYTES)

static u8 encrypted_image[IMAGE_SIZE_BYTES] __attribute__((aligned(64)));
static u8 recovered_image[IMAGE_SIZE_BYTES] __attribute__((aligned(64)));

static const u32 aes_key[4] = {
    0x2B7E1516U, 0x28AED2A6U, 0xABF71588U, 0x09CF4F3CU
};

static const u32 initial_counter[4] = {
    0xF0F1F2F3U, 0xF4F5F6F7U, 0xF8F9FAFBU, 0xFCFDFEFFU
};

extern void outbyte(char c);

/* Read the ARMv8 physical counter directly. This avoids any dependency on
 * xtime_l.h, which is not exported by every Vitis 2026.1 standalone BSP. */
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
    return ((u32)bytes[0] << 24) |
           ((u32)bytes[1] << 16) |
           ((u32)bytes[2] << 8)  |
           ((u32)bytes[3]);
}

static void unpack_be32(u32 word, u8 *bytes)
{
    bytes[0] = (u8)(word >> 24);
    bytes[1] = (u8)(word >> 16);
    bytes[2] = (u8)(word >> 8);
    bytes[3] = (u8)word;
}

static void load_key_and_counter(void)
{
    u32 index;

    for(index = 0; index < 4; ++index)
    {
        Xil_Out32(AES_BASE + REG_KEY0 + index * 4U, aes_key[index]);
        Xil_Out32(AES_BASE + REG_CTR0 + index * 4U, initial_counter[index]);
    }

    Xil_Out32(AES_BASE + REG_CONTROL, CTRL_LOAD_COUNTER);
}

static int process_image(const u8 *input, u8 *output)
{
    u32 offset;
    u32 word_index;
    u32 timeout;
    u32 status;

    load_key_and_counter();

    for(offset = 0; offset < IMAGE_SIZE_BYTES; offset += AES_BLOCK_BYTES)
    {
        for(word_index = 0; word_index < 4; ++word_index)
        {
            Xil_Out32(
                AES_BASE + REG_DIN0 + word_index * 4U,
                pack_be32(&input[offset + word_index * 4U])
            );
        }

        Xil_Out32(AES_BASE + REG_CONTROL, CTRL_CLEAR_DONE);
        Xil_Out32(AES_BASE + REG_CONTROL, CTRL_START);

        timeout = POLL_TIMEOUT;
        do
        {
            status = Xil_In32(AES_BASE + REG_STATUS);
            --timeout;
        }
        while(((status & STATUS_DONE) == 0U) && (timeout != 0U));

        if(timeout == 0U)
            return -1;

        for(word_index = 0; word_index < 4; ++word_index)
        {
            u32 word = Xil_In32(AES_BASE + REG_DOUT0 + word_index * 4U);
            unpack_be32(word, &output[offset + word_index * 4U]);
        }
    }

    return 0;
}

static int compare_buffers(const u8 *left, const u8 *right, u32 size)
{
    u32 index;
    for(index = 0; index < size; ++index)
        if(left[index] != right[index])
            return (int)index + 1;
    return 0;
}

static void send_bytes(const u8 *data, u32 size)
{
    u32 index;
    for(index = 0; index < size; ++index)
        outbyte((char)data[index]);
}

static void print_performance(const char *operation, u64 start, u64 end)
{
    u64 elapsed_counts = (u64)(end - start);
    u64 counter_hz = read_arm_counter_frequency();
    u64 elapsed_us;
    u64 throughput_kbps;
    u64 time_per_block_ns;

    if(counter_hz == 0U)
        counter_hz = 1U;

    elapsed_us = (elapsed_counts * 1000000ULL) / counter_hz;

    if(elapsed_us == 0U)
        elapsed_us = 1U;

    throughput_kbps = ((u64)IMAGE_SIZE_BYTES * 1000ULL) / elapsed_us;
    time_per_block_ns = (elapsed_us * 1000ULL) / (u64)IMAGE_BLOCKS;

    xil_printf("%s_TIME_US %u\r\n",
               operation, (unsigned int)elapsed_us);
    xil_printf("%s_THROUGHPUT_KBPS %u\r\n",
               operation, (unsigned int)throughput_kbps);
    xil_printf("%s_TIME_PER_BLOCK_NS %u\r\n",
               operation, (unsigned int)time_per_block_ns);
}

int main(void)
{
    int mismatch;
    u64 encryption_start;
    u64 encryption_end;
    u64 decryption_start;
    u64 decryption_end;

    init_platform();

    xil_printf("\r\nZCU104_AES_CTR_START\r\n");
    xil_printf("IMAGE 256 256 RGB888 %u\r\n",
               (unsigned int)IMAGE_SIZE_BYTES);
    xil_printf("AES_BLOCKS %u\r\n", (unsigned int)IMAGE_BLOCKS);

    Xil_Out32(AES_BASE + REG_CONTROL, CTRL_SOFT_RESET);

    xil_printf("ENCRYPTING\r\n");
    encryption_start = read_arm_counter();
    if(process_image(car_256_rgb, encrypted_image) != 0)
    {
        xil_printf("ERROR ACCELERATOR_TIMEOUT_ENCRYPT\r\n");
        cleanup_platform();
        return 1;
    }
    encryption_end = read_arm_counter();
    print_performance("ENCRYPTION", encryption_start, encryption_end);

    xil_printf("DECRYPTING\r\n");
    decryption_start = read_arm_counter();
    if(process_image(encrypted_image, recovered_image) != 0)
    {
        xil_printf("ERROR ACCELERATOR_TIMEOUT_DECRYPT\r\n");
        cleanup_platform();
        return 2;
    }
    decryption_end = read_arm_counter();
    print_performance("DECRYPTION", decryption_start, decryption_end);

    mismatch = compare_buffers(car_256_rgb, recovered_image, IMAGE_SIZE_BYTES);
    if(mismatch != 0)
    {
        xil_printf("ERROR RECOVERY_MISMATCH_AT_%d\r\n", mismatch - 1);
        cleanup_platform();
        return 3;
    }

    xil_printf("RECOVERY_PASS\r\n");
    xil_printf("CIPHERTEXT_BEGIN %u\r\n",
               (unsigned int)IMAGE_SIZE_BYTES);
    send_bytes(encrypted_image, IMAGE_SIZE_BYTES);
    xil_printf("\r\nCIPHERTEXT_END\r\n");

    xil_printf("RECOVERED_BEGIN %u\r\n",
               (unsigned int)IMAGE_SIZE_BYTES);
    send_bytes(recovered_image, IMAGE_SIZE_BYTES);
    xil_printf("\r\nRECOVERED_END\r\n");
    xil_printf("ZCU104_AES_CTR_DONE\r\n");

    cleanup_platform();
    return 0;
}
