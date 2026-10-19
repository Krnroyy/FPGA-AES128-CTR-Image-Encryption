/* Paired control-interface ablation: SAME raw commands on Stage 1 and Stage 2. */
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
#define REG_GUARD         0x68U
#define CTRL_RELEASE      0x10U

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
#define DMA_TIMEOUT       3000000U
#define GCM_TIMEOUT       300000000U
#define TAMPER_XOR_MASK   0x01U

/* Fixed public test vector already used by tb_ReleaseInterlock. */
static u8 encrypted_image[PROTECTED_CHUNK_BYTES] __attribute__((aligned(64)));
static u8 recovered_image[PROTECTED_CHUNK_BYTES] __attribute__((aligned(64)));
static const u32 aes_key[4] = {0U, 0U, 0U, 0U};
static u32 initial_iv[3] = {0U, 0U, 0U};
static u32 aad_words[4] = {0x01010300U, 0x00010007U, 0x00000015U, 0x00000001U};
static u32 image_size_bytes = 21U;
static XAxiDma axi_dma;


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

static int wait_for_dma(int wait_mm2s, int wait_s2mm)
{
    u32 timeout = DMA_TIMEOUT;
    while(((wait_mm2s && XAxiDma_Busy(&axi_dma, XAXIDMA_DMA_TO_DEVICE)) ||
           (wait_s2mm && XAxiDma_Busy(&axi_dma, XAXIDMA_DEVICE_TO_DMA))) && timeout != 0U)
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
    if(status != XST_SUCCESS || wait_for_dma(1, 0) != XST_SUCCESS)
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

#define DMA_BASE_TEST      0xA0010000U
#define DMA_MM2S_SR_TEST   0x04U
#define DMA_S2MM_SR_TEST   0x34U
#define DMA_ERRORS_TEST    0x00000770U
#define DMA_IOC_TEST       0x00001000U
#define PROBE_BYTES        64U
#define PROBE_VALUE        0xA5U


static const u8 vector_ciphertext[21] = {
    0x03,0x89,0xd8,0xcd,0x64,0xb3,0xa5,0x95,0xfb,0x21,0xc8,
    0xb2,0x7d,0xbf,0xf0,0x77,0xe7,0x84,0xb8,0xb8,0x5d
};
static const u32 vector_tag[4] = {
    0xc562f330U, 0xa2d904c0U, 0x169d61a0U, 0xdd0e85faU
};

static void delay_us_test(u32 microseconds)
{
    u64 start = read_arm_counter();
    u64 ticks = (read_arm_counter_frequency() * microseconds + 999999U) / 1000000U;
    while(read_arm_counter() - start < ticks) { }
}

static int reset_dma_test(void)
{
    u64 start = read_arm_counter();
    u64 limit = read_arm_counter_frequency();
    XAxiDma_Reset(&axi_dma);
    while(!XAxiDma_ResetIsDone(&axi_dma))
        if(read_arm_counter() - start > limit)
            return XST_FAILURE;
    XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    return XST_SUCCESS;
}

static u32 is_stage2;

static int begin_case(int wrong_tag)
{
    u32 i;
    Xil_Out32(GCM_BASE + REG_CONTROL,CTRL_SOFT_RESET);
    if(reset_dma_test() != XST_SUCCESS || protected_buffer_zeroize() != XST_SUCCESS)
        return XST_FAILURE;
    for(i=0U;i<21U;++i) encrypted_image[i]=vector_ciphertext[i];
    fill_buffer(recovered_image,PROBE_BYTES,PROBE_VALUE);
    if(protected_buffer_capture(encrypted_image,image_size_bytes) != XST_SUCCESS)
        return XST_FAILURE;
    /* Legitimate fixed context; no LOAD_IV, no authentication replay here. */
    Xil_Out32(GCM_BASE + REG_MODE,MODE_AUTH_ONLY);
    for(i=0U;i<4U;++i) {
        Xil_Out32(GCM_BASE + REG_KEY0+4U*i,aes_key[i]);
        Xil_Out32(GCM_BASE + REG_EXPECTED_TAG0+4U*i,
            vector_tag[i] ^ ((wrong_tag && i==3U) ? 1U : 0U));
        Xil_Out32(GCM_BASE + REG_AAD0+4U*i,aad_words[i]);
    }
    for(i=0U;i<3U;++i) Xil_Out32(GCM_BASE + REG_IV0+4U*i,initial_iv[i]);
    Xil_Out32(GCM_BASE + REG_AAD_BYTES,AAD_SIZE_BYTES);
    return XST_SUCCESS;
}

static int arm_destination(void)
{
    if(reset_dma_test() != XST_SUCCESS) return XST_FAILURE;
    fill_buffer(recovered_image,PROBE_BYTES,PROBE_VALUE);
    if(XAxiDma_SimpleTransfer(&axi_dma,(UINTPTR)recovered_image,image_size_bytes,
                             XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS)
        return XST_FAILURE;
    return (Xil_In32(DMA_BASE_TEST+0x30U) & 1U) ? XST_SUCCESS : XST_FAILURE;
}

static int exact_plaintext(void)
{
    u32 i;
    Xil_DCacheInvalidateRange((INTPTR)recovered_image,PROBE_BYTES);
    for(i=0U;i<PROBE_BYTES;++i)
        if(recovered_image[i] != (i<21U ? (u8)i : (u8)PROBE_VALUE)) return 0;
    return 1;
}

static int positive_control(void)
{
    u32 status;
    xil_printf("ABLATION_BEGIN AUTHENTICATED_CONTROL\r\n");
    if(begin_case(0) != XST_SUCCESS || prepare_gcm(MODE_AUTH_ONLY,vector_tag) != XST_SUCCESS ||
       protected_buffer_replay() != XST_SUCCESS ||
       poll_status(STATUS_DONE|STATUS_TAG_VALID,STATUS_DONE|STATUS_TAG_VALID) != XST_SUCCESS)
        return XST_FAILURE;
    status=Xil_In32(GCM_BASE+REG_STATUS);
    Xil_DCacheInvalidateRange((INTPTR)recovered_image,PROBE_BYTES);
    if((status & (STATUS_TAG_MATCH|STATUS_AUTH_FAIL)) != STATUS_TAG_MATCH ||
       !buffer_is_value(recovered_image,PROBE_BYTES,PROBE_VALUE)) return XST_FAILURE;
    if(arm_destination() != XST_SUCCESS) return XST_FAILURE;
    if(is_stage2) Xil_Out32(GCM_BASE+REG_CONTROL,CTRL_ENABLE|CTRL_RELEASE);
    else if(prepare_gcm(MODE_DECRYPT,vector_tag) != XST_SUCCESS) return XST_FAILURE;
    if(poll_status(STATUS_GCM_READY,STATUS_GCM_READY) != XST_SUCCESS ||
       protected_buffer_replay() != XST_SUCCESS || wait_for_dma(0,1) != XST_SUCCESS ||
       poll_status(STATUS_DONE|STATUS_TAG_VALID,STATUS_DONE|STATUS_TAG_VALID) != XST_SUCCESS ||
       !exact_plaintext()) return XST_FAILURE;
    status=Xil_In32(GCM_BASE+REG_STATUS);
    if((status & (STATUS_TAG_MATCH|STATUS_AUTH_FAIL)) != STATUS_TAG_MATCH) return XST_FAILURE;
    xil_printf("ABLATION_RESULT AUTHENTICATED_CONTROL EXACT_21_BYTES\r\n");
    return XST_SUCCESS;
}

static int raw_attempt(int wrong_tag)
{
    const char *name=wrong_tag ? "RAW_DECRYPT_BAD_TAG" : "RAW_DECRYPT_VALID_TAG";
    u32 guard,buffer,status,dma;
    xil_printf("ABLATION_BEGIN %s\r\n",name);
    if(begin_case(wrong_tag) != XST_SUCCESS || arm_destination() != XST_SUCCESS)
        return XST_FAILURE;
    /* Identical attack stream on BOTH hardware versions. No prior auth-only pass.
     * Delay permits setup to finish even on the original hardware. */
    Xil_Out32(GCM_BASE+REG_MODE,MODE_DECRYPT);
    Xil_Out32(GCM_BASE+REG_CONTROL,CTRL_LOAD_IV);
    delay_us_test(100U);
    Xil_Out32(GCM_BASE+REG_CONTROL,CTRL_ENABLE|CTRL_CLEAR_DONE);
    Xil_Out32(PROTECTED_BUFFER_BASE+BUFFER_REG_CONTROL,BUFFER_CTRL_REPLAY);
    delay_us_test(2000U);
    guard=Xil_In32(GCM_BASE+REG_GUARD);
    buffer=Xil_In32(PROTECTED_BUFFER_BASE+BUFFER_REG_STATUS);
    status=Xil_In32(GCM_BASE+REG_STATUS);
    dma=Xil_In32(DMA_BASE_TEST+DMA_S2MM_SR_TEST);
    Xil_DCacheInvalidateRange((INTPTR)recovered_image,PROBE_BYTES);
    xil_printf("ABLATION_STATE %s GUARD %08x BUFFER %08x GCM %08x S2MM %08x\r\n",
        name,(unsigned int)guard,(unsigned int)buffer,(unsigned int)status,(unsigned int)dma);
    if(is_stage2) {
        if((guard & 0xFFFF010CU) != 0x52470100U ||
           (buffer & (BUFFER_STATUS_IDLE|BUFFER_STATUS_ZEROIZE_DONE)) !=
                     (BUFFER_STATUS_IDLE|BUFFER_STATUS_ZEROIZE_DONE) ||
           (dma & (DMA_ERRORS_TEST|DMA_IOC_TEST)) != 0U ||
           !buffer_is_value(recovered_image,PROBE_BYTES,PROBE_VALUE)) return XST_FAILURE;
        xil_printf("ABLATION_RESULT %s BLOCKED_PROBE_UNCHANGED\r\n",name);
    } else {
        if((dma & (DMA_ERRORS_TEST|DMA_IOC_TEST)) != DMA_IOC_TEST ||
           (status & (STATUS_DONE|STATUS_TAG_VALID)) != (STATUS_DONE|STATUS_TAG_VALID) ||
           (status & (STATUS_TAG_MATCH|STATUS_AUTH_FAIL)) !=
                     (wrong_tag ? STATUS_AUTH_FAIL : STATUS_TAG_MATCH) ||
           !exact_plaintext()) return XST_FAILURE;
        xil_printf("ABLATION_RESULT %s EXPOSED_EXACT_21_BYTES %s\r\n",name,
                   wrong_tag ? "AUTH_FAIL" : "TAG_MATCH");
    }
    return XST_SUCCESS;
}

int main(void)
{
    u32 guard;
    int result;
    init_platform();
    xil_printf("\r\nPCF_RELEASE_ABLATION_START\r\n");
    guard=Xil_In32(GCM_BASE+REG_GUARD);
    if(guard==0U) is_stage2=0U;
    else if((guard & 0xFFFF0000U)==0x52470000U) is_stage2=1U;
    else { xil_printf("ABLATION_OVERALL FAIL UNKNOWN_HARDWARE\r\n");cleanup_platform();return 1; }
    xil_printf("ABLATION_PROFILE %s\r\n",is_stage2 ? "STAGE2_GUARD" : "STAGE1_TRUSTED_FIRMWARE");
    xil_printf("ABLATION_REGISTER_68 %08x\r\n",(unsigned int)guard);
#ifdef __OPTIMIZE__
    xil_printf("ABLATION_OPTIMIZATION_ENABLED 1\r\n");
#else
    xil_printf("ABLATION_OPTIMIZATION_ENABLED 0\r\n");
#endif
    result=initialize_dma();
    if(result==XST_SUCCESS) result=positive_control();
    if(result==XST_SUCCESS) result=raw_attempt(0);
    if(result==XST_SUCCESS) result=raw_attempt(1);
    if(result!=XST_SUCCESS)
        xil_printf("ABLATION_FAILURE_STATE GUARD %08x BUFFER %08x GCM %08x S2MM %08x\r\n",
            (unsigned int)Xil_In32(GCM_BASE+REG_GUARD),
            (unsigned int)Xil_In32(PROTECTED_BUFFER_BASE+BUFFER_REG_STATUS),
            (unsigned int)Xil_In32(GCM_BASE+REG_STATUS),
            (unsigned int)Xil_In32(DMA_BASE_TEST+DMA_S2MM_SR_TEST));
    Xil_Out32(GCM_BASE+REG_CONTROL,CTRL_SOFT_RESET);
    if(reset_dma_test()!=XST_SUCCESS) result=XST_FAILURE;
    if(protected_buffer_zeroize()!=XST_SUCCESS) result=XST_FAILURE;
    zeroize_buffer(encrypted_image,sizeof(encrypted_image));
    zeroize_buffer(recovered_image,sizeof(recovered_image));
    xil_printf("ABLATION_OVERALL %s\r\n",result==XST_SUCCESS ? "PASS" : "FAIL");
    cleanup_platform();
    return result==XST_SUCCESS ? 0 : 1;
}
