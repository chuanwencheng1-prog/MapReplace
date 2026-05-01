//
//  SandboxEscape.m
//  MapReplacerApp
//
//  DarkSword 集成层 (FilzaJailedDS 风格)
//
//  构建开关 (由 Makefile 注入):
//    MR_WITH_DARKSWORD=1  → 链接 kexploit/sandbox_escape/apfs_own，真实逃逸
//    MR_WITH_DARKSWORD=0  → 回退 NSFileManager (用于无越狱/kfd 环境联调)
//
//  DarkSword 原始实现见: https://github.com/34306/FilzaJailedDS
//      - sandbox_escape.h/m    : 改写 sandbox ext 扩展 (proc_ro→ucred→cr_label→sandbox)
//      - apfs_own.h/m          : 直接写 apfs_fsnode 的 uid/gid/mode
//      - kexploit/*.m          : krw 原语 (kread/kwrite) + offsets
//      - kpf/, XPF/            : 通过 kernelcache 模式匹配自动求 offsets
//
#import "SandboxEscape.h"
#import <sys/stat.h>
#import <sys/types.h>
#import <dirent.h>
#import <unistd.h>
#import <fcntl.h>

#ifndef MR_WITH_DARKSWORD
#define MR_WITH_DARKSWORD 1
#endif

#if MR_WITH_DARKSWORD
// ---- DarkSword 真实实现 (由 fetch_darksword.sh 拉入源码树) ----
#include "sandbox_escape.h"
#include "apfs_own.h"
#include "kexploit/kexploit_opa334.h"
#include "kexploit/krw.h"
#include "kexploit/kutils.h"
#endif

// ============================================================
// 状态
// ============================================================
static BOOL g_escaped = NO;
static dispatch_once_t g_init_once;

// ============================================================
// 初始化
// ============================================================

BOOL SandboxEscapeInit(void) {
#if MR_WITH_DARKSWORD
    dispatch_once(&g_init_once, ^{
        NSLog(@"[SBX] >>> Starting DarkSword kexploit init...");

        // 1. 启动 kernel R/W 原语 (opa334 XPF + kfd/krw)
        int kxok = kexploit_opa334();
        if (kxok != 0) {
            NSLog(@"[SBX] kexploit_opa334 FAILED (rc=%d)", kxok);
            return;
        }
        NSLog(@"[SBX] kexploit ready (krw available)");

        // 2. 解析 self_proc
        uint64_t self_proc = proc_self();
        if (!self_proc) {
            NSLog(@"[SBX] proc_self() returned 0, abort");
            return;
        }
        NSLog(@"[SBX] self_proc = 0x%llx", self_proc);

        // 3. 执行 sandbox_escape: 改写扩展链为 "/" + 类替换为 app-sandbox.read-write
        int rc = sandbox_escape(self_proc);
        if (rc != 0) {
            NSLog(@"[SBX] sandbox_escape FAILED (rc=%d)", rc);
            return;
        }

        // 4. 提权到 root (替换当前 p_ucred 为 launchd 的)
        rc = sandbox_elevate_to_root(self_proc);
        if (rc != 0) {
            NSLog(@"[SBX] sandbox_elevate_to_root FAILED (rc=%d) — 继续 (MAC 已清但 DAC 受限)", rc);
        }

        // 5. 探测验证: 能否 open /var/mobile/.sbx_test
        int fd = open("/var/mobile/.sbx_probe", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            close(fd);
            unlink("/var/mobile/.sbx_probe");
            g_escaped = YES;
            NSLog(@"[SBX] *** SANDBOX ESCAPED (verified) ***");
        } else {
            NSLog(@"[SBX] escape probe FAILED (errno=%d)", errno);
        }
    });
    return g_escaped;
#else
    NSLog(@"[SBX] DarkSword 未集成 (MR_WITH_DARKSWORD=0)，运行在标准沙箱");
    return NO;
#endif
}

BOOL SandboxEscapeIsActive(void) { return g_escaped; }

// ============================================================
// 文件操作封装
// ============================================================

BOOL SandboxEscapeCopyFile(NSString *src, NSString *dst) {
    if (!src.length || !dst.length) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];

    // 确保目标目录存在
    NSString *dstDir = [dst stringByDeletingLastPathComponent];
    if (dstDir.length && ![fm fileExistsAtPath:dstDir]) {
        [fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 若已存在，先删除
    if ([fm fileExistsAtPath:dst]) {
        NSError *rmErr = nil;
        [fm removeItemAtPath:dst error:&rmErr];
        if (rmErr) {
            // NSFileManager 失败，尝试 POSIX unlink (逃逸后 DAC 检查可能通过)
            unlink(dst.fileSystemRepresentation);
        }
    }

    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:src toPath:dst error:&err];
    if (ok) return YES;

    NSLog(@"[SBX] NSFileManager copy 失败: %@ → 尝试 POSIX read/write", err.localizedDescription);

    // POSIX fallback: 读源 → 写目标 (逃逸后可跨容器)
    int fsrc = open(src.fileSystemRepresentation, O_RDONLY);
    if (fsrc < 0) { NSLog(@"[SBX] open src fail errno=%d", errno); return NO; }
    int fdst = open(dst.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fdst < 0) { close(fsrc); NSLog(@"[SBX] open dst fail errno=%d", errno); return NO; }

    uint8_t buf[64 * 1024];
    ssize_t n;
    BOOL good = YES;
    while ((n = read(fsrc, buf, sizeof(buf))) > 0) {
        ssize_t w = write(fdst, buf, (size_t)n);
        if (w != n) { good = NO; break; }
    }
    close(fsrc);
    close(fdst);
    if (!good) { unlink(dst.fileSystemRepresentation); return NO; }
    sync();
    return YES;
}

BOOL SandboxEscapeRemoveFile(NSString *path) {
    if (!path.length) return NO;
    NSError *e = nil;
    if ([[NSFileManager defaultManager] removeItemAtPath:path error:&e]) return YES;
    return unlink(path.fileSystemRepresentation) == 0;
}

BOOL SandboxEscapeChown(NSString *path, uid_t uid, gid_t gid) {
#if MR_WITH_DARKSWORD
    if (!g_escaped || !path.length) return NO;
    int rc = apfs_own(path.fileSystemRepresentation, uid, gid);
    return rc == 0;
#else
    return NO;
#endif
}

// ============================================================
// 目标容器 Paks 目录定位
// ------------------------------------------------------------
// 遍历 /var/mobile/Containers/Data/Application/{UUID}/.com.apple.mobile_container_manager.metadata.plist
// 找到 MCMMetadataIdentifier == bundleID 的容器
// 返回 <UUID>/Documents/ShadowTrackerExtra/Saved/Paks
// ============================================================

static NSString *g_target_paks_cache;

NSString *SandboxEscapeFindPaksForBundleID(NSString *bundleID) {
    if (!g_escaped || !bundleID.length) return nil;
    if (g_target_paks_cache) return g_target_paks_cache;

    NSString *root = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *uuids = [fm contentsOfDirectoryAtPath:root error:nil];
    if (!uuids.count) {
        NSLog(@"[SBX] 无法枚举 %@", root);
        return nil;
    }

    for (NSString *uuid in uuids) {
        NSString *base = [root stringByAppendingPathComponent:uuid];
        NSString *meta = [base stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:meta];
        NSString *ident = dict[@"MCMMetadataIdentifier"];
        if (![ident isEqualToString:bundleID]) continue;

        NSString *paks = [base stringByAppendingPathComponent:@"Documents/ShadowTrackerExtra/Saved/Paks"];
        if (![fm fileExistsAtPath:paks]) {
            [fm createDirectoryAtPath:paks withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSLog(@"[SBX] 命中容器 %@ → %@", uuid, paks);
        g_target_paks_cache = [paks copy];
        return g_target_paks_cache;
    }

    NSLog(@"[SBX] 未找到 bundleID=%@ 对应的容器", bundleID);
    return nil;
}
