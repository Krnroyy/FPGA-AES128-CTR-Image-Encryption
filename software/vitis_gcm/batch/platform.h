#ifndef ZCU104_AES_GCM_BATCH_PLATFORM_H
#define ZCU104_AES_GCM_BATCH_PLATFORM_H

#include "xil_cache.h"

static inline void init_platform(void)
{
    Xil_ICacheEnable();
    Xil_DCacheEnable();
}

static inline void cleanup_platform(void)
{
    Xil_DCacheDisable();
    Xil_ICacheDisable();
}

#endif
