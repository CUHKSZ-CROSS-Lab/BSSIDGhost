/*
 * tests/objc-stub/os/lock.h
 *
 * BSSIDGhost —— 用于在非 Darwin 主机上做语法检查的 os_unfair_lock 桩。
 *
 * 真实实现在 libplatform（Darwin）；这里只声明接口与静态初始化宏，
 * 使 hooks 下 ObjC 源码的 -fsyntax-only 检查能够通过。声明与 Darwin 头文件保持一致。
 */

#ifndef BG_STUB_OS_LOCK_H
#define BG_STUB_OS_LOCK_H

#include <stdbool.h>
#include <stdint.h>

typedef struct os_unfair_lock_s {
    uint32_t _os_unfair_lock_opaque;
} os_unfair_lock;

typedef os_unfair_lock *os_unfair_lock_t;

#define OS_UNFAIR_LOCK_INIT ((os_unfair_lock){0})

void os_unfair_lock_lock(os_unfair_lock_t lock);
void os_unfair_lock_unlock(os_unfair_lock_t lock);
bool os_unfair_lock_trylock(os_unfair_lock_t lock);

#endif /* BG_STUB_OS_LOCK_H */
