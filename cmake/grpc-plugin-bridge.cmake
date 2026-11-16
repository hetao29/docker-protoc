# 仅用于本项目的 gRPC 插件构建，不用于构建完整的上游 protoc。
# 最终消息生成器来自官方 protoc 归档，libprotoc 在这里仅承担插件协议/描述符处理。
# 保留通用 compiler 实现与语言命名辅助（例如 PHP GeneratedClassName），
# 跳过不交付的各语言消息生成后端，避免重复编译另一整套 protoc。
include_guard(GLOBAL)

function(docker_protoc_limit_compiler_library)
    if(NOT TARGET libprotoc)
        message(FATAL_ERROR "Expected protobuf libprotoc target for gRPC plugin bridge")
    endif()
    get_target_property(compiler_sources libprotoc SOURCES)
    set(bridge_sources)
    foreach(source IN LISTS compiler_sources)
        if(source MATCHES "(^|/)compiler/[^/]+/.*\\.cc$" AND NOT source MATCHES "(^|/)names\\.cc$")
            continue()
        endif()
        list(APPEND bridge_sources "${source}")
    endforeach()
    set_property(TARGET libprotoc PROPERTY SOURCES "${bridge_sources}")
endfunction()

# project() 时目标尚未创建，延迟到根目录完成配置后再调整目标。
# 全局 include_guard 避免 Abseil/protobuf 子项目重复注册该调用。
cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL docker_protoc_limit_compiler_library)
