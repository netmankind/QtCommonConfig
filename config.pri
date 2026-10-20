# ============================================================
# config.pri —— 通用工程配置（qmake）
# 适用：Qt 5.15 / Qt 6.x，Windows / Linux / macOS，MSVC / MinGW / GCC / Clang
#
# 用法：在主 .pro 中  include($$PWD/config.pri)
#   可选开关（需写在 include 之前）：
#     CONFIG += console_app       # 控制台程序（默认 GUI 程序，无控制台黑窗）
#     CONFIG += no_translations   # 不处理多语言（默认自动 lrelease）
#     CONFIG += keep_deprecated   # 不禁用 Qt 旧 API（默认禁用 5.15 之前的废弃 API）
#     CONFIG += strict_warnings   # 更严格的警告（MSVC /W4，GCC/Clang 额外 -Wextra）
#     CONFIG += no_warnings       # 不主动追加警告选项
#     CONFIG += static_runtime    # MSVC 静态链接 CRT（/MT、/MTd），CRT指C/C++运行时库，Qt 官方预编译包（ Qt6Core.dll、Qt5Widgets.dll等）是用 **`/MD`** 动态编译的，用 Qt 官方 DLL 时，保持默认 `/MD`，不要加 `static_runtime`
#     CONFIG += auto_deploy       # Windows 构建后自动运行 windeployqt
#     CONFIG += version_stamp     # 每次构建后删除版本目标文件以刷新版本号（需工程自带版本源文件）
#   其他变量：
#     VERSION_FILE_BASENAME = xxx  # 版本文件名（不含扩展名），默认 version
# ============================================================

# ============================================================
# 一、通用 C++ 标准与 Qt 特性
# ============================================================
# C++17（Qt5 / Qt6 均支持；CONFIG *= 去重，避免重复追加）
CONFIG *= c++17
# 大资源 / 大 GIF 支持（资源超过一定体积时需要）
CONFIG *= resources_big
CONFIG *= gif
# 单配置构建：去掉空的 debug / release 目录
CONFIG -= debug_and_release
# 多语言：自动调用 lrelease 生成 qm（无 TRANSLATIONS 时不产生副作用）
CONFIG *= lrelease
# 预编译头支持（Qt6 qmake 不支持该特性，仅 Qt5 启用；具体头文件由工程 PRECOMPILED_HEADER 指定）
!greaterThan(QT_MAJOR_VERSION, 5): CONFIG *= precompile_header

# Release 下保留日志上下文（文件名、函数名、行号），便于定位问题
DEFINES *= QT_MESSAGELOGCONTEXT
# 使用 Qt 废弃 API 时发出警告
DEFINES *= QT_DEPRECATED_WARNINGS
# 默认禁用 Qt 5.15 之前的废弃 API（Qt5 / Qt6 均识别）
!CONFIG(keep_deprecated) {
    DEFINES *= QT_DISABLE_DEPRECATED_BEFORE=0x050F00
    # Qt6.5+ 专属宏，Qt5 不识别，条件添加
    greaterThan(QT_MAJOR_VERSION, 5): DEFINES *= QT_DISABLE_DEPRECATED_UP_TO=0x050F00
}

# ============================================================
# 二、编译器通用选项
# ============================================================
# ---------- MSVC ----------
win32-msvc* {
    # 源文件 / 执行字符集统一 UTF-8（否则中文在源码中易乱码）
    QMAKE_CXXFLAGS += /utf-8
    # /MP：多进程并行编译，显著提升多文件工程编译速度
    QMAKE_CXXFLAGS += /MP
    # 静态链接CRT默认动态链接 /MD、/MDd），CRT指C/C++运行时库（`vcruntime140.dll`、`msvcp140.dll` 等）
    CONFIG(static_runtime) {
        QMAKE_CXXFLAGS_DEBUG   += /MTd
        QMAKE_CXXFLAGS_RELEASE += /MT
    }
}
# ---------- MinGW / GCC / Clang ----------
win32-g++|gcc|clang {
    # 统一源码字符集为 UTF-8
    QMAKE_CXXFLAGS += -finput-charset=UTF-8 -fexec-charset=UTF-8
}
# ---------- 警告级别 ----------
!CONFIG(no_warnings) {
    win32-msvc* {
        QMAKE_CXXFLAGS += /W3
        CONFIG(strict_warnings): QMAKE_CXXFLAGS += /W4
    }
    win32-g++|gcc|clang {
        QMAKE_CXXFLAGS += -Wall
        CONFIG(strict_warnings): QMAKE_CXXFLAGS += -Wextra
    }
}

# ============================================================
# 三、Qt6 MSVC qmake 系统库补全
# Qt6 的 qmake 不会把 mkspecs 里 QMAKE_LIBS_GUI 的系统库自动加到链接行，
# 而 Qt5 qmake 会自动加。这里仅对 Qt6 + MSVC 补齐，避免 LNK2019
# （SetWindowPos、GetWindowLongPtrW 等均位于 user32）
# ============================================================
win32-msvc*:greaterThan(QT_MAJOR_VERSION, 5) {
    LIBS += gdi32.lib comdlg32.lib oleaut32.lib imm32.lib winmm.lib \
            ws2_32.lib ole32.lib uuid.lib user32.lib advapi32.lib
}

# ============================================================
# 四、打印系统信息
# ============================================================
message("Computer system OS:"$$QMAKE_HOST.os)
message("CPU cores:"$$QMAKE_HOST.cpu_count)
message("Qt Version="$$[QT_VERSION])
message("build for "$$QT_ARCH)

# ============================================================
# 五、获取工程名
# ============================================================
DIR_NAME = $$basename(PWD)                          # 当前目录名（basename 收变量名，PWD 前不加 $$）
CANDIDATE = $$PWD/$${DIR_NAME}.pro                  # 拼出候选路径（exists() 收"值"）
exists($$CANDIDATE) {
    MAIN_PROJECT = $$DIR_NAME                       # 目录名 == 工程名 → 直接用
} else {
    PRO_LIST     = $$files($$PWD/*.pro)             # 取根目录第一个 .pro 去后缀
    MAIN_PRO     = $$first(PRO_LIST)
    PRO_BASE     = $$basename(MAIN_PRO)
    MAIN_PROJECT = $$replace(PRO_BASE, \.pro$, "")
}
message(MAIN_PROJECT = $$MAIN_PROJECT)

!isEmpty(MAIN_PROJECT) {
    PROJECT_NAME = $$MAIN_PROJECT
} else {
    PROJECT_NAME = $$TARGET
}
message("PROJECT_NAME = $$PROJECT_NAME")

# ============================================================
# 六、TARGET 默认命名（工程未显式指定 TARGET 时）
#   Release: <工程名>   Debug: <工程名>_d
# ============================================================
isEmpty(TARGET) {
    TARGET = $$PROJECT_NAME
    CONFIG(debug, debug|release): TARGET = $${TARGET}_d
}

# ============================================================
# 七、操作系统位数与编译器标识
# ============================================================
contains(QT_ARCH, x86_64)|contains(QT_ARCH, arm64)|contains(QT_ARCH, aarch64) {
    BITS = 64
} else: contains(QT_ARCH, i.86) {
    BITS = 32
} else {
    BITS =
    message(警告: 未识别的架构 $$QT_ARCH)
}
gcc {
    DIR_COMPILER = GCC$$BITS
} else: msvc {
    DIR_COMPILER = MSVC$$BITS
} else: clang {
    DIR_COMPILER = CLANG$$BITS
} else {
    DIR_COMPILER = UNKNOWN
    message(警告: 未识别的编译器 QMAKE_XSPEC = $$QMAKE_XSPEC)
}
message(DIR_COMPILER = $$DIR_COMPILER)

# ============================================================
# 八、平台检测
# ============================================================
# ---------- Windows ----------
win32 {
    contains(QT_ARCH, x86_64) {
        DIR_PLATFORM = Win64
    } else {
        DIR_PLATFORM = Win32
    }
    win32-g++ {
        DIR_COMPILER = MinGW$$BITS
        TOOLCHAIN_TAG = mingw
    }
    win32-msvc* {
        DIR_COMPILER = MSVC$$BITS
        TOOLCHAIN_TAG = msvc
    }
}
# ---------- x86 Linux ----------
linux-g++|linux-clang {
    contains(QT_ARCH, x86_64) {
        DIR_PLATFORM = Linux-x86_64
    } else {
        DIR_PLATFORM = Linux-x86
    }
    DIR_COMPILER = GCC$$BITS
    TOOLCHAIN_TAG = gcc
}
# ---------- ARM Linux ----------
my-linux-arm-qt|linux-arm-gnueabi-g++ {
    DIR_PLATFORM = Linux-arm
    DEFINES += BUILD_FOR_ARM
    target.path = /home/root
    INSTALLS += target
    # 构建步骤里用 DEFINES += AM437X / A5D3 区分板卡
    contains(DEFINES, AM437X): DIR_COMPILER = AM437X
    contains(DEFINES, A5D3):   DIR_COMPILER = A5D3
}
# ---------- macOS ----------
macx {
    DIR_PLATFORM = macOS
    contains(QT_ARCH, arm64): DIR_PLATFORM = macOS-arm64
}

# ============================================================
# 九、编译模式
# ============================================================
CONFIG(debug, debug|release) {
    FILE_POSTFIX = D
    DIR_COMPILEMODE = Debug
} else: CONFIG(release, debug|release) {
    FILE_POSTFIX =
    DIR_COMPILEMODE = Release
}

# ============================================================
# 十、应用类型（GUI / 控制台）
# 仅对 TEMPLATE=app 生效；库工程不受影响
# ============================================================
equals(TEMPLATE, app) {
    CONFIG(console_app) {
        # 控制台程序：保留控制台输出
        win32: CONFIG += console
    } else {
        # GUI 程序：关闭控制台黑窗，使用 Windows 子系统
        CONFIG -= console
        win32: CONFIG += windows
    }
}

# ============================================================
# 十一、中间文件目录（moc / rcc / ui / obj）
# ============================================================
MOC_DIR     = $${DIR_COMPILEMODE}/moc
RCC_DIR     = $${DIR_COMPILEMODE}/rcc
UI_DIR      = $${DIR_COMPILEMODE}/ui
OBJECTS_DIR = $${DIR_COMPILEMODE}/obj

# ============================================================
# 十二、输出目录（工程上层目录的影子构建产物目录）
# ============================================================
DEST_LIB = $$clean_path($$PWD/../$${PROJECT_NAME}-qt$$[QT_VERSION]-$${DIR_COMPILER}-bin)
DESTDIR  = $$clean_path($$PWD/../$${PROJECT_NAME}-qt$$[QT_VERSION]-$${DIR_COMPILER}-bin)

# ============================================================
# 十三、多语言 qm 输出目录（exe 同级 translations/）
# 必须放在 DESTDIR 定义之后
# ============================================================
!CONFIG(no_translations) {
    LRELEASE_DIR = $$DESTDIR/translations
    !exists($$LRELEASE_DIR): mkpath($$LRELEASE_DIR)
}

# ============================================================
# 十四、可选：自动部署 windeployqt（Windows）
# 启用 CONFIG += auto_deploy
# ============================================================
win32:CONFIG(auto_deploy) {
    WINDEPLOYQT = $$shell_quote($$shell_path($$[QT_INSTALL_BINS]/windeployqt.exe))
    QMAKE_POST_LINK += $$WINDEPLOYQT $$shell_quote($$shell_path($$DESTDIR/$$TARGET.exe)) $$escape_expand(\\n\\t)
}

# ============================================================
# 十五、可选：版本号每次构建刷新
# 启用 CONFIG += version_stamp（需工程自带版本源文件，编译后删除其目标文件强制重编）
# 版本文件名（不含扩展名）默认 version，其他工程可覆盖：
#   VERSION_FILE_BASENAME = appversion
# ============================================================
CONFIG(version_stamp) {
    isEmpty(VERSION_FILE_BASENAME): VERSION_FILE_BASENAME = version
    VERSION_OBJ = $$OBJECTS_DIR/$${VERSION_FILE_BASENAME}.*
    win32 {
        QMAKE_POST_LINK += $$QMAKE_DEL_FILE /q /f $$shell_quote($$system_path($$VERSION_OBJ)) || exit 0 $$escape_expand(\\n\\t)
    } else {
        QMAKE_POST_LINK += $$QMAKE_DEL_FILE $$system_path($$VERSION_OBJ) || exit 0 $$escape_expand(\\n\\t)
    }
}
