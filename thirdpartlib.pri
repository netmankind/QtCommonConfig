# ============================================================
# thirdpartlib.pri —— 第三方预编译库（OpenSSL / libssh2 / libcurl）通用配置
# 适用：Qt 5.15 / Qt 6.x，Windows(MSVC / MinGW) / Linux / Android
#
# 用法（主 .pro，通常在 include(config.pri) 之后）：
#   include(QtCommonConfig/thirdpartlib.pri)
#
# 可选开关（写在 include 之前）：
#   CONFIG += static_thirdparty      # 静态链接第三方库（默认动态 shared）
#   CONFIG += no_thirdparty_deploy   # 动态库不自动复制 dll（默认构建后拷到 DESTDIR）
#   CONFIG += skip_thirdparty        # 整体跳过：不链接、不复制
#
# 可选变量（覆盖默认值）：
#   THIRDPART_ROOT   = E:/open_source/openssl-curl-ssh2/build  # 预编译库根目录
#   OPENSSL_VERSION  = 3.5.9         # OpenSSL 版本（目录名片段；1.1.1w 同理）
#   LIBSSH2_VERSION  = 1.11.1
#   LIBCURL_VERSION  = 8.23.0
#
# 目录约定（与预编译产物命名一致）：
#   <根目录>/<工具链目录>/<组件>-<版本>-openssl-<版本>-<shared|static>
#   例：build/mingw64-qt6/curl-8.23.0-openssl-3.5.9-shared
# ============================================================

# ---------- 0. 整体跳过 ----------
CONFIG(skip_thirdparty) {
    message("thirdpartlib: 已通过 skip_thirdparty 跳过")
} else {

# ---------- 1. 版本与链接方式 ----------
isEmpty(OPENSSL_VERSION):  OPENSSL_VERSION  = 3.5.9
isEmpty(LIBSSH2_VERSION):  LIBSSH2_VERSION  = 1.11.1
isEmpty(LIBCURL_VERSION):  LIBCURL_VERSION  = 8.23.0
isEmpty(THIRDPART_ROOT):   THIRDPART_ROOT  = E:/open_source/openssl-curl-ssh2/build

# 静态 / 动态目录后缀
CONFIG(static_thirdparty): TP_LINKAGE = static
else:                       TP_LINKAGE = shared

# ---------- 2. 工具链 / 平台构建目录 ----------
win32-g++ {
    greaterThan(QT_MAJOR_VERSION, 5): TP_TOOLCHAIN_DIR = mingw64-qt6
    else:                             TP_TOOLCHAIN_DIR = mingw64-qt5
}
win32-msvc*: TP_TOOLCHAIN_DIR = msvc-x64
android:     TP_TOOLCHAIN_DIR = android-$$QT_ARCH
# Linux 走系统安装包，无预编译目录，TP_TOOLCHAIN_DIR 留空

!isEmpty(TP_TOOLCHAIN_DIR) {
    TP_BUILD_ROOT = $$clean_path($$THIRDPART_ROOT/$$TP_TOOLCHAIN_DIR)

    # 包目录名（与预编译目录命名约定一致）
    SSL_PKG  = openssl-$${OPENSSL_VERSION}-$${TP_LINKAGE}
    SSH2_PKG = ssh2-$${LIBSSH2_VERSION}-openssl-$${OPENSSL_VERSION}-$${TP_LINKAGE}
    CURL_PKG = curl-$${LIBCURL_VERSION}-openssl-$${OPENSSL_VERSION}-$${TP_LINKAGE}

    SSL_PATH  = $$clean_path($$TP_BUILD_ROOT/$$SSL_PKG)
    SSH2_PATH = $$clean_path($$TP_BUILD_ROOT/$$SSH2_PKG)
    CURL_PATH = $$clean_path($$TP_BUILD_ROOT/$$CURL_PKG)

    message("thirdpartlib: 链接方式=$$TP_LINKAGE, 构建目录=$$TP_BUILD_ROOT")
    message("thirdpartlib: OpenSSL = $$SSL_PATH")
    message("thirdpartlib: libssh2 = $$SSH2_PATH")
    message("thirdpartlib: libcurl = $$CURL_PATH")
}

# ---------- 3. Windows（预编译包） ----------
win32:!android {
    INCLUDEPATH *= $$SSL_PATH/include $$SSH2_PATH/include $$CURL_PATH/include

    # 存在性提示：头文件缺失时给出明确警告，避免静默链接失败
    !exists($$SSL_PATH/include/openssl/ssl.h): message("警告: 未找到 OpenSSL 头文件 $$SSL_PATH")
    !exists($$SSH2_PATH/include/libssh2.h):   message("警告: 未找到 libssh2 头文件 $$SSH2_PATH")
    !exists($$CURL_PATH/include/curl/curl.h):  message("警告: 未找到 libcurl 头文件 $$CURL_PATH")

    win32-g++ {
        LIBS *= -L$$SSL_PATH/lib  -lssl -lcrypto
        LIBS *= -L$$SSH2_PATH/lib -lssh2
        LIBS *= -L$$CURL_PATH/lib -lcurl
    }
    win32-msvc* {
        LIBS *= $$shell_quote($$SSL_PATH/lib/libssl.lib)
        LIBS *= $$shell_quote($$SSL_PATH/lib/libcrypto.lib)
        LIBS *= $$shell_quote($$SSH2_PATH/lib/libssh2.lib)
        # MSVC 导入库命名：动态 libcurl_imp.lib，静态 libcurl.lib
        CONFIG(static_thirdparty): LIBS *= $$shell_quote($$CURL_PATH/lib/libcurl.lib)
        else:                       LIBS *= $$shell_quote($$CURL_PATH/lib/libcurl_imp.lib)
    }

    # 静态链接补充：静态宏 + OpenSSL 依赖的 Windows 系统库
    CONFIG(static_thirdparty) {
        DEFINES *= CURL_STATICLIB
        DEFINES *= LIBSSH2_STATICLIB
        win32-msvc* {
            LIBS *= ws2_32.lib wsock32.lib crypt32.lib advapi32.lib user32.lib gdi32.lib
        } else {
            LIBS *= -lws2_32 -lwsock32 -lcrypt32 -ladvapi32 -luser32 -lgdi32
        }
    }
}

# ---------- 4. Linux（系统安装包，无预编译路径） ----------
linux-g++ | linux-clang {
    LIBS *= -lssl -lcrypto -lssh2 -lcurl
}

# ---------- 5. Android（NDK 交叉编译） ----------
android {
    INCLUDEPATH *= $$SSL_PATH/include $$SSH2_PATH/include $$CURL_PATH/include
    LIBS *= -L$$SSL_PATH/lib  -lssl -lcrypto
    LIBS *= -L$$SSH2_PATH/lib -lssh2
    LIBS *= -L$$CURL_PATH/lib -lcurl

    # 动态库打包进 APK（静态包无 .so，跳过）
    !CONFIG(static_thirdparty) {
        ANDROID_EXTRA_LIBS += \
            $$SSL_PATH/lib/libssl.so \
            $$SSL_PATH/lib/libcrypto.so \
            $$SSH2_PATH/lib/libssh2.so \
            $$CURL_PATH/lib/libcurl.so
    }
}

# ---------- 6. Windows 动态库自动复制（仅 shared 需要） ----------
# 静态链接不产生 dll；no_thirdparty_deploy 关闭复制；复制命令串含空格，保留 +=
win32:!android:!CONFIG(static_thirdparty):!CONFIG(no_thirdparty_deploy) {
    isEmpty(DESTDIR): DESTDIR = $$OUT_PWD
    THIRD_DLLS = $$files($$SSL_PATH/bin/*.dll) \
                 $$files($$SSH2_PATH/bin/*.dll) \
                 $$files($$CURL_PATH/bin/*.dll)
    for(dll, THIRD_DLLS) {
        QMAKE_POST_LINK += $$QMAKE_COPY $$shell_quote($$shell_path($$dll)) \
                           $$shell_quote($$shell_path($$DESTDIR)) $$escape_expand(\\n\\t)
    }
}

} # CONFIG(skip_thirdparty) 结束
