TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = MapReplacerApp

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MapReplacerApp

# ============================================================
# 本项目的业务源码 (UI + MapManager + SandboxEscape wrapper)
# ============================================================
MapReplacerApp_FILES  = main.m AppDelegate.m MainViewController.m
MapReplacerApp_FILES += MapManager.m SandboxEscape.m

# ============================================================
# DarkSword 沙箱逃逸源码 (来自 FilzaJailedDS，需先跑 fetch_darksword.sh)
# 若未拉取，可在命令行传入 MR_WITH_DARKSWORD=0 禁用
# ============================================================
MR_WITH_DARKSWORD ?= 1

ifeq ($(MR_WITH_DARKSWORD),1)
    # 核心
    MapReplacerApp_FILES += DarkSword/sandbox_escape.m DarkSword/apfs_own.m

    # kexploit 原语 (krw / kread / kwrite / offsets / xpaci / vnode / kutils)
    MapReplacerApp_FILES += DarkSword/kexploit/kexploit_opa334.m
    MapReplacerApp_FILES += DarkSword/kexploit/krw.m
    MapReplacerApp_FILES += DarkSword/kexploit/kutils.m
    MapReplacerApp_FILES += DarkSword/kexploit/offsets.m
    MapReplacerApp_FILES += DarkSword/kexploit/vnode.m

    # utils
    MapReplacerApp_FILES += DarkSword/utils/file.c DarkSword/utils/hexdump.c DarkSword/utils/process.c

    # kpf (patchfinder)
    MapReplacerApp_FILES += DarkSword/kpf/patchfinder.m

    # XPF core
    MapReplacerApp_FILES += DarkSword/XPF/src/xpf.c DarkSword/XPF/src/common.c \
                             DarkSword/XPF/src/decompress.c DarkSword/XPF/src/bad_recovery.c \
                             DarkSword/XPF/src/non_ppl.c DarkSword/XPF/src/ppl.c

    # ChOma (Mach-O / CodeSignature 解析)
    MapReplacerApp_FILES += DarkSword/XPF/external/ChOma/src/arm64.c \
                             DarkSword/XPF/external/ChOma/src/Base64.c \
                             DarkSword/XPF/external/ChOma/src/BufferedStream.c \
                             DarkSword/XPF/external/ChOma/src/CodeDirectory.c \
                             DarkSword/XPF/external/ChOma/src/CSBlob.c \
                             DarkSword/XPF/external/ChOma/src/DER.c \
                             DarkSword/XPF/external/ChOma/src/DyldSharedCache.c \
                             DarkSword/XPF/external/ChOma/src/Entitlements.c \
                             DarkSword/XPF/external/ChOma/src/Fat.c \
                             DarkSword/XPF/external/ChOma/src/FileStream.c \
                             DarkSword/XPF/external/ChOma/src/Host.c \
                             DarkSword/XPF/external/ChOma/src/MachO.c \
                             DarkSword/XPF/external/ChOma/src/MachOLoadCommand.c \
                             DarkSword/XPF/external/ChOma/src/MemoryStream.c \
                             DarkSword/XPF/external/ChOma/src/PatchFinder.c \
                             DarkSword/XPF/external/ChOma/src/PatchFinder_arm64.c \
                             DarkSword/XPF/external/ChOma/src/Util.c

    DARKSWORD_CFLAGS = -DMR_WITH_DARKSWORD=1 \
        -I$(PWD)/DarkSword \
        -I$(PWD)/DarkSword/XPF/src \
        -I$(PWD)/DarkSword/XPF/external/ChOma/include \
        -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable \
        -Wno-incompatible-pointer-types -Wno-incompatible-pointer-types-discards-qualifiers \
        -Wno-deprecated-declarations -Wno-nonportable-include-path -Wno-format
    DARKSWORD_LIBS = z sandbox
    DARKSWORD_FRAMEWORKS = IOKit CoreFoundation
    DARKSWORD_PRIV_FRAMEWORKS = IOSurface
else
    DARKSWORD_CFLAGS = -DMR_WITH_DARKSWORD=0
endif

# ============================================================
# 编译标志
# ============================================================
MapReplacerApp_CFLAGS     = -fobjc-arc $(DARKSWORD_CFLAGS)
MapReplacerApp_CCFLAGS    = $(MapReplacerApp_CFLAGS)
MapReplacerApp_OBJCFLAGS  = $(MapReplacerApp_CFLAGS)
MapReplacerApp_OBJCCFLAGS = $(MapReplacerApp_CFLAGS)

MapReplacerApp_FRAMEWORKS         = UIKit Foundation CoreGraphics $(DARKSWORD_FRAMEWORKS)
MapReplacerApp_PRIVATE_FRAMEWORKS = $(DARKSWORD_PRIV_FRAMEWORKS)
MapReplacerApp_LIBRARIES          = $(DARKSWORD_LIBS)

# Info.plist / 代码签名
MapReplacerApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# ============================================================
# 辅助目标: 拉取 DarkSword 源码
# ============================================================
darksword-fetch::
	@bash ./fetch_darksword.sh
