//
//  SandboxEscape.h
//  MapReplacerApp
//
//  DarkSword 沙箱逃逸统一 API
//  ------------------------------------------------------------------
//  内部调用 FilzaJailedDS/DarkSword 的 kexploit + sandbox_escape + apfs_own。
//  如果 DarkSword 源码未编入 (宏 MR_WITH_DARKSWORD=0)，则所有函数回退到
//  标准 POSIX/NSFileManager，应用仍可在自身沙箱内部工作。
//
#ifndef SANDBOX_ESCAPE_H
#define SANDBOX_ESCAPE_H

#import <Foundation/Foundation.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 初始化 DarkSword: kexploit_opa334_init() → sandbox_escape() → elevate_to_root()
/// 必须在后台线程调用（会阻塞数百毫秒-数秒）。多次调用幂等。
/// @return YES 表示逃逸成功 (获得跨容器 R+W)；NO 表示回退模式。
BOOL SandboxEscapeInit(void);

/// 检查当前逃逸是否激活
BOOL SandboxEscapeIsActive(void);

/// 复制文件 (src → dst)。逃逸激活后可跨容器；否则仅限当前沙箱。
BOOL SandboxEscapeCopyFile(NSString *src, NSString *dst);

/// 删除文件 (容器外也可)
BOOL SandboxEscapeRemoveFile(NSString *path);

/// 修改文件属主 (仅在逃逸激活后有效，使用 apfs_own 直接改 fsnode)
BOOL SandboxEscapeChown(NSString *path, uid_t uid, gid_t gid);

/// 在 /var/mobile/Containers/Data/Application/ 下查找指定 bundleID 所属容器，
/// 返回其 Documents/ShadowTrackerExtra/Saved/Paks 目录绝对路径 (不存在时会创建)。
/// 若逃逸未激活则返回 nil。
NSString * _Nullable SandboxEscapeFindPaksForBundleID(NSString *bundleID);

#ifdef __cplusplus
}
#endif

#endif /* SANDBOX_ESCAPE_H */
