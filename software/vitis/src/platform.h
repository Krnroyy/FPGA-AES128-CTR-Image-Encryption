#ifndef PLATFORM_H
#define PLATFORM_H

/*
 * The Vitis standalone runtime performs the required early processor setup.
 * These wrappers keep the application independent of template-specific
 * platform.c files. If a generated Vitis application already provides its own
 * platform.h/platform.c, keep that generated pair instead of this header.
 */
static inline void init_platform(void)
{
}

static inline void cleanup_platform(void)
{
}

#endif

