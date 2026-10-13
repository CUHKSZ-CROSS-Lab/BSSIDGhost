# BSSIDGhost - theos 打包（rootless / Dopamine，iOS 15.0-16.6.x）
#
# 用法（需已配置 $THEOS）：
#   scripts/build.sh --toolchain theos        # 推荐：先过授权闸，再生成过滤器与随包配置
#   make package                              # 绕过 build.sh 直接打包（不推荐，跳过授权闸）
#
# 注意：deb 路线的产物名遵循 theos 约定，为 BSSIDGhost.dylib；
#       `libbssidghost.dylib` 是 clang 手工注入路线的产物名（见 scripts/build.sh）。

export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.0
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BSSIDGhost
BSSIDGhost_FILES = $(wildcard hooks/*.m) $(wildcard hooks/*.c)
BSSIDGhost_CFLAGS = -fobjc-arc -Ihooks -Wall -Wextra

include $(THEOS_MAKE_PATH)/tweak.mk
