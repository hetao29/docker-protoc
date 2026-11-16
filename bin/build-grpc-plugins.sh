#!/bin/sh
# Docker grpc-build 阶段入口：仅交付 C++/PHP/Python/Ruby 四个原生 gRPC 生成器。
# 任一源码下载、校验、配置或编译失败，都会使整个镜像构建失败。
set -eu
# 读取 gRPC 版本、固定提交及每个源码归档的 SHA-256。
. /opt/docker-protoc/toolchain.env

# 此目录由 Dockerfile 的 BuildKit cache mount 提供，不会写入最终镜像。
# 按 gRPC 版本隔离源码与构建目录，按归档 SHA-256 复用已校验的下载。
cache_root=/var/cache/docker-protoc/grpc
source_dir="$cache_root/$GRPC_VERSION-archives"
mkdir -p "$cache_root/downloads"

# fetch_source 组织/仓库 固定提交 归档SHA256 解压目录
# 只接受锁定内容；标记文件在成功解压后写入，避免把中断的解压当作完成。
fetch_source() {
    repo=$1
    commit=$2
    expected_sha=$3
    destination=$4
    marker="$destination/.docker-protoc-source-sha256"
    # 已完成相同归档的解压时直接复用，保留 CMake/Ninja 的增量构建结果。
    if [ -f "$marker" ] && [ "$(cat "$marker")" = "$expected_sha" ]; then
        return
    fi
    archive="$cache_root/downloads/$expected_sha.tar.gz"
    # 缓存不存在或校验不通过才下载；codeload 直接获取指定提交，不克隆无关历史。
    if ! printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum --check --status >/dev/null 2>&1; then
        curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 600 \
            "https://codeload.github.com/$repo/tar.gz/$commit" --output "$archive"
        printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum --check --status
    fi
    mkdir -p "$destination"
    # 去掉归档的仓库名顶层目录，保持上游 CMake 期待的 third_party 相对路径。
    tar -xzf "$archive" --strip-components=1 -C "$destination"
    printf '%s\n' "$expected_sha" > "$marker"
}

# 主源码和三个构建依赖均来自 GitHub 官方的固定提交归档，并逐一验证 SHA-256。
# 依赖提交与该 gRPC 发行的子模块一致；这里的 protobuf 仅供编译插件，不替换最终 protoc。
fetch_source grpc/grpc "$GRPC_COMMIT" "$GRPC_SOURCE_SHA256" "$source_dir"
fetch_source abseil/abseil-cpp "$GRPC_ABSEIL_COMMIT" "$GRPC_ABSEIL_SHA256" "$source_dir/third_party/abseil-cpp"
fetch_source protocolbuffers/protobuf "$GRPC_PROTOBUF_COMMIT" "$GRPC_PROTOBUF_SHA256" "$source_dir/third_party/protobuf"
fetch_source grpc/grpc-proto "$GRPC_PROTO_COMMIT" "$GRPC_PROTO_SHA256" "$source_dir/third_party/grpc-proto"
# 使用 Release/C++17 构建；依赖库采用静态形式，最终仅复制插件可执行文件。
# 关闭 gRPC/protobuf/utf8_range 安装与测试：本项目不交付其开发库或 CMake export 配置，
# 同时避免构建期依赖的安装导出集合不一致。禁用自动下载，防止引入未锁定源码。
# SSL/c-ares/RE2/zlib 使用构建阶段的系统开发包；关闭项目未使用的 C#/Node/ObjC 插件目标。
# 使用已校验的官方 protoc 作为外部编译器；libprotoc 仅保留 gRPC 插件的通用桥接和命名辅助。
# 私有 CMake 钩子裁剪重复的消息后端，因此只构建下面列出的四个插件目标。
cmake -S "$source_dir" -B "$source_dir/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_PROJECT_INCLUDE_BEFORE=/opt/docker-protoc/grpc-plugin-bridge.cmake \
    -DWITH_PROTOC=/usr/local/bin/protoc -Dprotobuf_BUILD_LIBPROTOC=ON \
    -DBUILD_SHARED_LIBS=OFF -DgRPC_INSTALL=OFF -DgRPC_BUILD_TESTS=OFF \
    -Dprotobuf_INSTALL=OFF -Dutf8_range_ENABLE_INSTALL=OFF \
    -DgRPC_DOWNLOAD_ARCHIVES=OFF \
    -DgRPC_SSL_PROVIDER=package -DgRPC_CARES_PROVIDER=package \
    -DgRPC_RE2_PROVIDER=package -DgRPC_ZLIB_PROVIDER=package \
    -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
    -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF
# 只构建四个生成器及其必要依赖，不构建完整 gRPC 服务运行库。
# BUILD_JOBS 由 Docker 构建参数传入，限制并发以控制内存占用。
cmake --build "$source_dir/build" --parallel "${BUILD_JOBS:-2}" \
    --target grpc_cpp_plugin grpc_php_plugin grpc_python_plugin grpc_ruby_plugin
install -d /opt/plugins
# install -s 剥离调试符号，0755 保证 protoc 可以执行插件；该目录随后被复制到最终镜像。
for language in cpp php python ruby; do
    install -s -m 0755 "$source_dir/build/grpc_${language}_plugin" /opt/plugins/
done
