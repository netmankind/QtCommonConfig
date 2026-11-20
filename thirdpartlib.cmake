# =============================================================================
# thirdpartlib.cmake —— 第三方预编译库（OpenSSL / libssh2 / libcurl）通用配置
# 与 thirdpartlib.pri 对应；适用 Qt 5.15 / Qt 6.x，Windows(MSVC / MinGW) / Linux / Android
#
# 用法（主 CMakeLists.txt，add_executable/add_library 之后）：
#   include(${CMAKE_CURRENT_SOURCE_DIR}/QtCommonConfig/thirdpartlib.cmake)
#   qt_common_link_thirdparty(foo)
# 不需要第三方库时，不调用该函数即可。
#
# 可选开关变量（include 之前设置，对应 pri 的 CONFIG 开关）：
#   QT_COMMON_STATIC_THIRDPARTY     静态链接第三方库（默认动态 shared）
#   QT_COMMON_NO_THIRDPARTY_DEPLOY 动态库不自动复制 dll（默认构建后拷到输出目录）
#
# 可选变量（覆盖默认值）：
#   THIRDPART_ROOT    预编译库根目录
#   OPENSSL_VERSION   OpenSSL 版本（目录名片段；1.1.1w 同理）
#   LIBSSH2_VERSION   libssh2 版本
#   LIBCURL_VERSION   libcurl 版本
#
# 目录约定（与预编译产物命名一致）：
#   <根目录>/<工具链目录>/<组件>-<版本>-openssl-<版本>-<shared|static>
#   例：build/mingw64-qt6/curl-8.23.0-openssl-3.5.9-shared
# =============================================================================

# ---- 1. 版本与根目录默认值（工程可在 include 前覆盖） ----
if(NOT DEFINED THIRDPART_ROOT)
    set(THIRDPART_ROOT "E:/open_source/openssl-curl-ssh2/build")
endif()
if(NOT DEFINED OPENSSL_VERSION)
    set(OPENSSL_VERSION "3.5.9")
endif()
if(NOT DEFINED LIBSSH2_VERSION)
    set(LIBSSH2_VERSION "1.11.1")
endif()
if(NOT DEFINED LIBCURL_VERSION)
    set(LIBCURL_VERSION "8.23.0")
endif()

# -----------------------------------------------------------------------------
# 链接 OpenSSL / libssh2 / libcurl 到指定目标
# 参数：
#   target —— 主可执行目标 / 库目标名
# -----------------------------------------------------------------------------
function(qt_common_link_thirdparty target)

    # ---- 链接方式 ----
    if(QT_COMMON_STATIC_THIRDPARTY)
        set(tp_linkage static)
    else()
        set(tp_linkage shared)
    endif()

    # ---- 2. 工具链 / 平台构建目录 ----
    if(ANDROID)
        set(tp_toolchain_dir "android-${CMAKE_ANDROID_ARCH_ABI}")
    elseif(MSVC)
        set(tp_toolchain_dir "msvc-x64")
    elseif(MINGW)
        if(QT_VERSION_MAJOR GREATER 5)
            set(tp_toolchain_dir "mingw64-qt6")
        else()
            set(tp_toolchain_dir "mingw64-qt5")
        endif()
    else()
        # Linux 走系统安装包，无预编译目录，工具链目录留空
        set(tp_toolchain_dir "")
    endif()

    if(tp_toolchain_dir)
        set(tp_build_root "${THIRDPART_ROOT}/${tp_toolchain_dir}")
        set(ssl_path  "${tp_build_root}/openssl-${OPENSSL_VERSION}-${tp_linkage}")
        set(ssh2_path "${tp_build_root}/ssh2-${LIBSSH2_VERSION}-openssl-${OPENSSL_VERSION}-${tp_linkage}")
        set(curl_path "${tp_build_root}/curl-${LIBCURL_VERSION}-openssl-${OPENSSL_VERSION}-${tp_linkage}")
        message(STATUS "thirdpartlib: 链接方式=${tp_linkage}, 构建目录=${tp_build_root}")
        message(STATUS "thirdpartlib: OpenSSL=${ssl_path}")
        message(STATUS "thirdpartlib: libssh2=${ssh2_path}")
        message(STATUS "thirdpartlib: libcurl=${curl_path}")
    endif()

    # ---- 4. Linux：系统安装包，无预编译路径 ----
    if(LINUX)
        target_link_libraries(${target} PRIVATE ssl crypto ssh2 curl)
        return()
    endif()

    # ---- 5. Android：NDK 交叉编译 ----
    if(ANDROID)
        target_include_directories(${target} PRIVATE
            "${ssl_path}/include" "${ssh2_path}/include" "${curl_path}/include")
        target_link_libraries(${target} PRIVATE
            "-L${ssl_path}/lib"  ssl crypto
            "-L${ssh2_path}/lib" ssh2
            "-L${curl_path}/lib" curl)

        # 动态库打包进 APK（静态包无 .so，跳过）
        if(NOT QT_COMMON_STATIC_THIRDPARTY)
            list(APPEND CMAKE_ANDROID_EXTRA_LIBS
                "${ssl_path}/lib/libssl.so"
                "${ssl_path}/lib/libcrypto.so"
                "${ssh2_path}/lib/libssh2.so"
                "${curl_path}/lib/libcurl.so")
            set(CMAKE_ANDROID_EXTRA_LIBS "${CMAKE_ANDROID_EXTRA_LIBS}" PARENT_SCOPE)
        endif()
        return()
    endif()

    # ---- 3. Windows 预编译包 ----
    target_include_directories(${target} PRIVATE
        "${ssl_path}/include" "${ssh2_path}/include" "${curl_path}/include")

    # 存在性提示：头文件缺失时给出明确警告，避免静默链接失败
    if(NOT EXISTS "${ssl_path}/include/openssl/ssl.h")
        message(WARNING "未找到 OpenSSL 头文件 ${ssl_path}")
    endif()
    if(NOT EXISTS "${ssh2_path}/include/libssh2.h")
        message(WARNING "未找到 libssh2 头文件 ${ssh2_path}")
    endif()
    if(NOT EXISTS "${curl_path}/include/curl/curl.h")
        message(WARNING "未找到 libcurl 头文件 ${curl_path}")
    endif()

    if(MSVC)
        target_link_libraries(${target} PRIVATE
            "${ssl_path}/lib/libssl.lib"
            "${ssl_path}/lib/libcrypto.lib"
            "${ssh2_path}/lib/libssh2.lib")
        # MSVC 导入库命名：动态 libcurl_imp.lib，静态 libcurl.lib
        if(QT_COMMON_STATIC_THIRDPARTY)
            target_link_libraries(${target} PRIVATE "${curl_path}/lib/libcurl.lib")
        else()
            target_link_libraries(${target} PRIVATE "${curl_path}/lib/libcurl_imp.lib")
        endif()
    else()
        target_link_libraries(${target} PRIVATE
            "-L${ssl_path}/lib"  ssl crypto
            "-L${ssh2_path}/lib" ssh2
            "-L${curl_path}/lib" curl)
    endif()

    # 静态链接补充：静态宏 + OpenSSL 依赖的 Windows 系统库
    if(QT_COMMON_STATIC_THIRDPARTY)
        target_compile_definitions(${target} PRIVATE CURL_STATICLIB LIBSSH2_STATICLIB)
        target_link_libraries(${target} PRIVATE
            ws2_32 wsock32 crypt32 advapi32 user32 gdi32)
    endif()

    # ---- 6. Windows 动态库自动复制（仅 shared 需要） ----
    # 静态链接不产生 dll；QT_COMMON_NO_THIRDPARTY_DEPLOY 关闭复制
    if(NOT QT_COMMON_STATIC_THIRDPARTY AND NOT QT_COMMON_NO_THIRDPARTY_DEPLOY)
        file(GLOB third_dlls
            "${ssl_path}/bin/*.dll"
            "${ssh2_path}/bin/*.dll"
            "${curl_path}/bin/*.dll")
        if(third_dlls)
            add_custom_command(TARGET ${target} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${third_dlls} "$<TARGET_FILE_DIR:${target}>"
                COMMENT "Copying thirdparty DLLs next to the executable")
        endif()
    endif()

endfunction()
