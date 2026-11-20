# =============================================================================
# config.cmake —— 通用工程配置（CMake），与 config.pri 对应
# 适用：Qt 5.15 / Qt 6.x，Windows / Linux / macOS，MSVC / MinGW / GCC / Clang
#
# 用法（主 CMakeLists.txt，project() 与 add_executable/add_library 之后）：
#   include(${CMAKE_CURRENT_SOURCE_DIR}/QtCommonConfig/config.cmake)
#   add_executable(foo ...)
#   qt_common_configure_target(foo)        # 通用宏 / 编译器选项 / 系统库补全
#   qt_common_set_output_dir(foo)          # 影子构建输出目录（可选）
#
# 可选开关变量（include 之前设置，对应 pri 的 CONFIG 开关）：
#   QT_COMMON_KEEP_DEPRECATED   不禁用 Qt 5.15 之前的废弃 API（默认禁用）
#   QT_COMMON_STRICT_WARNINGS   严格警告（MSVC /W4，GCC/Clang 额外 -Wextra）
#   QT_COMMON_NO_WARNINGS        不主动追加警告级别
#   QT_COMMON_STATIC_RUNTIME    MSVC 静态链接 CRT（/MT、/MTd；Qt 官方 DLL 下保持默认 /MD）
# =============================================================================

# -----------------------------------------------------------------------------
# 配置目标：通用编译定义、编译器选项、系统库补全
# 参数：
#   target —— 主可执行目标 / 库目标名
# -----------------------------------------------------------------------------
function(qt_common_configure_target target)

    # ---- 通用编译定义（与 config.pri 第一节 DEFINES 对齐） ----
    target_compile_definitions(${target} PRIVATE
        QT_MESSAGELOGCONTEXT      # Release 下保留日志上下文（文件名 / 函数 / 行号）
        QT_DEPRECATED_WARNINGS    # 使用废弃 API 时发出警告
        QT_USE_QSTRINGBUILDER     # QString 拼接走 QStringBuilder 优化
    )

    # 默认禁用 Qt 5.15 之前的废弃 API；需要保留时在 include 前置 QT_COMMON_KEEP_DEPRECATED
    if(NOT QT_COMMON_KEEP_DEPRECATED)
        target_compile_definitions(${target} PRIVATE
            QT_DISABLE_DEPRECATED_BEFORE=0x050F00
        )
        # Qt6.5+ 专属宏，Qt5 不识别，按主版本条件添加
        if(QT_VERSION_MAJOR GREATER 5)
            target_compile_definitions(${target} PRIVATE
                QT_DISABLE_DEPRECATED_UP_TO=0x050F00
            )
        endif()
    endif()

    # ---- MSVC 选项（与 config.pri 第二节 win32-msvc* 对齐） ----
    if(MSVC)
        target_compile_options(${target} PRIVATE
            /utf-8              # 源文件 / 执行字符集统一 UTF-8，避免中文乱码
            /MP                 # 多进程并行编译
            /Zc:__cplusplus     # 正确报告 __cplusplus 宏
            /permissive-        # 严格标准合规；第三方旧头报警时可在工程侧去掉
        )

        # 警告级别
        if(NOT QT_COMMON_NO_WARNINGS)
            if(QT_COMMON_STRICT_WARNINGS)
                target_compile_options(${target} PRIVATE /W4)
            else()
                target_compile_options(${target} PRIVATE /W3)
            endif()
        endif()

        # Release 保留 PDB：/Zi 生成独立 PDB 且不影响优化；链接侧 /DEBUG 输出 PDB，
        # 同时补回裁剪选项，避免 /DEBUG 默认退回 /OPT:NOREF /OPT:NOICF
        target_compile_options(${target} PRIVATE $<$<CONFIG:Release>:/Zi>)
        target_link_options(${target} PRIVATE
            $<$<CONFIG:Release>:/DEBUG /OPT:REF /OPT:ICF>
            /NOEXP              # 禁止生成 .exp 导出中间文件
        )

        # 非库工程禁止生成导入库 .lib；DLL / 静态库的 .lib 是导入库 / 库本体，必须保留
        get_target_property(target_type ${target} TYPE)
        if(NOT target_type STREQUAL "STATIC_LIBRARY" AND NOT target_type STREQUAL "SHARED_LIBRARY")
            target_link_options(${target} PRIVATE /NOIMPLIB)
        endif()

        # 静态 CRT（默认动态 /MD、/MDd；Qt 官方预编译包为 /MD，不要随意开启）
        if(QT_COMMON_STATIC_RUNTIME)
            target_compile_options(${target} PRIVATE
                $<$<CONFIG:Debug>:/MTd>
                $<$<CONFIG:Release>:/MT>
            )
        endif()

        # Qt6 MSVC 系统库补全：Qt6 的 CMake / qmake 不会把 GUI 系统库自动加到链接行，
        # 补齐 user32 / gdi32 等，避免 LNK2019（SetWindowPos、GetWindowLongPtrW 等）
        if(QT_VERSION_MAJOR GREATER 5)
            target_link_libraries(${target} PRIVATE
                gdi32 comdlg32 oleaut32 imm32 winmm
                ws2_32 ole32 uuid user32 advapi32
            )
        endif()
    endif()

    # ---- MinGW / GCC / Clang 选项（与 config.pri 第二节 gcc|clang 对齐） ----
    if(MINGW OR CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE
            -finput-charset=UTF-8
            -fexec-charset=UTF-8
        )

        if(NOT QT_COMMON_NO_WARNINGS)
            if(QT_COMMON_STRICT_WARNINGS)
                target_compile_options(${target} PRIVATE -Wall -Wextra)
            else()
                target_compile_options(${target} PRIVATE -Wall)
            endif()
        endif()

        # MinGW 把 GCC / STL 运行时静态链入，部署时少带 libgcc / libstdc++ DLL
        if(MINGW)
            target_link_options(${target} PRIVATE -static-libgcc -static-libstdc++)
        endif()
    endif()

endfunction()

# -----------------------------------------------------------------------------
# 设置影子构建输出目录（与 config.pri 第十二节 DESTDIR 对齐）
# 目录：<工程目录>/../<工程名>-qt<Qt完整版本>-<工具链>-bin
# 参数：
#   target —— 主可执行目标名
# -----------------------------------------------------------------------------
function(qt_common_set_output_dir target)

    if(MINGW)
        set(toolchain_name mingw)
    elseif(MSVC)
        set(toolchain_name msvc)
    else()
        set(toolchain_name "${CMAKE_CXX_COMPILER_ID}")
    endif()

    set(qt_full_version ${Qt${QT_VERSION_MAJOR}Core_VERSION})
    set(bin_dir
        ${CMAKE_CURRENT_SOURCE_DIR}/../${PROJECT_NAME}-qt${qt_full_version}-${toolchain_name}-bin
    )

    # 同时覆盖单配置与多配置（VS）生成器，避免再自动加 Debug / Release 子目录
    set_target_properties(${target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${bin_dir})
    foreach(config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
        set_target_properties(${target} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY_${config} ${bin_dir}
        )
    endforeach()

endfunction()

# -----------------------------------------------------------------------------
# 可选：把当前 git 短哈希注入编译宏 APP_BUILD_GIT；非 git 工程 / git 不在 PATH 时
# 回退为 dev，不报错。代码里直接使用宏 APP_BUILD_GIT 即可。
# 参数：
#   target —— 主可执行目标名
# -----------------------------------------------------------------------------
function(qt_common_add_git_hash target)

    set(git_hash dev)
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND ${GIT_EXECUTABLE} -C ${CMAKE_CURRENT_SOURCE_DIR}
                    rev-parse --short HEAD
            OUTPUT_VARIABLE git_hash
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(NOT git_hash)
            set(git_hash dev)
        endif()
    endif()

    target_compile_definitions(${target} PRIVATE APP_BUILD_GIT="${git_hash}")

endfunction()
