# QtCommonConfig

Qt 工程通用配置集合，适用于 Qt 5.15 / Qt 6.x，Windows / Linux / macOS，MSVC / MinGW / GCC / Clang。

## 内容

| 文件 | 说明 |
|---|---|
| `config.pri` | qmake 通用工程配置 |
| `config.cmake` | CMake 通用工程配置（与 `config.pri` 对应） |
| `thirdpartlib.pri` | OpenSSL / libssh2 / libcurl 第三方预编译库通用配置 |
| `thirdpartlib.cmake` | 第三方预编译库 CMake 配置（与 `thirdpartlib.pri` 对应） |

## 使用方法

### config.pri

1. 将 `config.pri` 复制到工程根目录；
2. 在主 `.pro` 中引入：

```qmake
include(config.pri)
```

### config.cmake

1. 将 `config.cmake` 放到工程的 `QtCommonConfig/` 目录（或随 submodule 引入）；
2. 在主 `CMakeLists.txt` 中引入，并在目标创建后调用通用函数：

```cmake
include(${CMAKE_CURRENT_SOURCE_DIR}/QtCommonConfig/config.cmake)
qt_common_print_build_info()                        # 打印平台 / 编译器 / Qt 版本信息（可选）

add_executable(foo ...)
qt_common_configure_target(foo)                    # C++17、通用宏 / 编译器选项 / 子系统 / 系统库补全
qt_common_set_output_dir(foo)                      # 影子构建输出目录（可选）
qt_common_refresh_version_on_build(foo)            # 每次构建刷新版本时间（对应 version_stamp，可选）
qt_common_deploy_windows(foo)                      # Windows 构建后 windeployqt（对应 auto_deploy，可选）
```

可选开关变量（include 之前设置）：

| qmake 开关 | CMake 变量 | 作用 |
|---|---|---|
| `CONFIG += keep_deprecated` | `QT_COMMON_KEEP_DEPRECATED` | 不禁用 Qt 5.15 之前的废弃 API（默认禁用） |
| `CONFIG += strict_warnings` | `QT_COMMON_STRICT_WARNINGS` | 更严格警告（MSVC `/W4`，GCC/Clang 额外 `-Wextra`） |
| `CONFIG += no_warnings` | `QT_COMMON_NO_WARNINGS` | 不主动追加警告选项 |
| `CONFIG += static_runtime` | `QT_COMMON_STATIC_RUNTIME` | MSVC 静态链接 CRT（`/MT`、`/MTd`；Qt 官方 DLL 下不建议） |
| `CONFIG += console_app` | `QT_COMMON_CONSOLE_APP` | 控制台程序（默认 GUI 程序，Windows 下不挂控制台子系统） |
| `CONFIG += strict_qt` | `QT_COMMON_STRICT_QT` | 严格迭代器（`QT_STRICT_ITERATORS`，默认关闭） |

### CMake 侧未重复实现的项（机制等价或工程专属）

| config.pri 项 | 不在 cmake 侧重复的原因 |
|---|---|
| `resources_big` / `gif`、`debug_and_release` | 属 qmake 资源与单/多配置构建选项；CMake 由生成器与 AUTORCC 机制管理，无对应开关 |
| `precompile_header` | 按需使用 `target_precompile_headers()`；工程未使用，不默认开启 |
| `MOC_DIR` / `RCC_DIR` / `UI_DIR` / `OBJECTS_DIR` | CMake 的 AUTOMOC / AUTOUIC / AUTORCC 自动管理中间产物，无需手工指定目录 |
| `TRANSLATIONS` 清单与 qm 拷贝 | 翻译文件列表与部署路径由各工程通过 `qt_add_translation` + POST_BUILD 拷贝维护 |
| 第十七节 RC 版本信息 / 图标 | CMake 不自动生成 `.rc`；需要时工程自带 `.rc` 并加入目标源清单 |
| `QT_NO_KEYWORDS`、`QT_NO_CAST_FROM_ASCII` 等备用宏 | 属代码纪律级开关，需工程侧清理代码后按需在 `target_compile_definitions` 开启 |
| Android ABI / SDK 版本变量 | Android 打包由 NDK 工具链与 Gradle / `androiddeployqt` 管理，不经本母版 |
| CPU 核数（`QMAKE_HOST.cpu_count`） | CMake 无可靠跨平台内置变量；`print_build_info` 仅输出系统 / 架构 / 位数 / 编译器 / Qt 版本 |

### 默认开启

- C++17、大资源 / 大 GIF、单配置构建
- 日志上下文（`QT_MESSAGELOGCONTEXT`）、废弃 API 警告、禁用 Qt 5.15 之前的旧 API
- MSVC：`/utf-8`、`/MP` 多进程编译、`/W3`
- GCC / Clang：UTF-8、`-Wall`
- **Qt6 MSVC 自动补齐系统库**（user32、gdi32 等，修复 `LNK2019`）
- TARGET 默认命名（Release 为工程名、Debug 加 `_d`）
- GUI 程序自动关闭控制台、使用 Windows 子系统
- 统一中间目录（moc / rcc / ui / obj）
- 统一输出目录：`工程名-qt版本-工具链-bin`（位于**工程目录的上一级**）
- qm 输出到 exe 同级 `translations/`

### 关于共享使用（把本 config.pri 放共享目录再被各工程 include）

- 工程名取自 `$$_PRO_FILE_`（正在构建的 `.pro`），**不用 `$$PWD`**：
  在被 include 的 `.pri` 里 `$$PWD` 指向 `.pri` 自身目录，会把工程名/输出目录错算到共享目录上。
- 输出目录基准是 `$$_PRO_FILE_PWD_`（`.pro` 所在目录），因此无论 config.pri 放在哪，产物都输出到工程目录的上一级。
- 不再采用"取目录中第一个 `.pro`"的兜底，避免同目录存在多个 `.pro` 时按字母序选错工程。

### 可选开关（写在 `include(config.pri)` 之前）

| 开关 | 作用 |
|---|---|
| `CONFIG += console_app` | 控制台程序（默认 GUI 程序，无控制台黑窗） |
| `CONFIG += no_translations` | 不处理多语言（默认自动 lrelease） |
| `CONFIG += keep_deprecated` | 不禁用 Qt 旧 API |
| `CONFIG += strict_warnings` | 更严格警告（MSVC `/W4`，GCC/Clang 额外 `-Wextra`） |
| `CONFIG += no_warnings` | 不主动追加警告选项 |
| `CONFIG += static_runtime` | MSVC 静态链接 CRT（`/MT`、`/MTd`；Qt 官方 DLL 下不建议） |
| `CONFIG += auto_deploy` | Windows 构建后自动运行 windeployqt |
| `CONFIG += version_stamp` | 每次构建后删除版本目标文件以刷新版本号 |

### 可选变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `VERSION_FILE_BASENAME` | `version` | 版本文件名（不含扩展名），配合 `version_stamp` 使用 |

### thirdpartlib.pri / thirdpartlib.cmake（第三方预编译库）

qmake：在 `include(config.pri)` 之后引入：

```qmake
include(QtCommonConfig/thirdpartlib.pri)
```

CMake：引入后在目标创建后调用链接函数：

```cmake
include(${CMAKE_CURRENT_SOURCE_DIR}/QtCommonConfig/thirdpartlib.cmake)
qt_common_link_thirdparty(foo)
```

按工具链自动选择预编译目录（MinGW Qt6 / Qt5、MSVC x64、Android ABI），路径统一归一化；默认动态链接（shared），可切换静态。

| qmake 开关 | CMake 变量 | 作用 |
|---|---|---|
| `CONFIG += static_thirdparty` | `QT_COMMON_STATIC_THIRDPARTY` | 静态链接第三方库（目录后缀 `static`，加 `CURL_STATICLIB` / `LIBSSH2_STATICLIB` 与 Windows 系统库） |
| `CONFIG += no_thirdparty_deploy` | `QT_COMMON_NO_THIRDPARTY_DEPLOY` | 动态库不自动复制 dll（默认构建后把 `bin/*.dll` 拷到输出目录） |

不需要第三方库时，qmake 不 include、CMake 不调用函数即可。

| 变量 | 默认 | 说明 |
|---|---|---|
| `THIRDPART_ROOT` | `E:/open_source/openssl-curl-ssh2/build` | 预编译库根目录 |
| `OPENSSL_VERSION` | `3.5.9` | OpenSSL 版本（目录名片段） |
| `LIBSSH2_VERSION` | `1.11.1` | libssh2 版本 |
| `LIBCURL_VERSION` | `8.23.0` | libcurl 版本 |

- Windows：按工具链加头文件路径与链接库；MSVC curl 动态为 `libcurl_imp.lib`、静态为 `libcurl.lib`。
- Linux：直接链系统库（`-lssl -lcrypto -lssh2 -lcurl`），无需预编译路径。
- Android：动态库进 `ANDROID_EXTRA_LIBS`；静态包无 `.so`，自动跳过。
- 头文件缺失时 `message` 给出明确警告，避免静默链接失败。

## 提交者

netmankind <netmankind@outlook.com>
