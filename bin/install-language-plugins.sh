#!/bin/sh
# Docker language-plugins 阶段入口，按 dart/jvm/web 分组安装；未传参数时安装全部组。
# 分组 RUN 使成功安装的组件形成独立镜像层，后续下载失败时无需重做前面的安装。
set -eu
# 版本与 SHA-256 只从锁文件读取；PATH/PUB_CACHE 由 Dockerfile 提供。
. /opt/docker-protoc/toolchain.env
# 临时目录存放解压和待安装文件，退出或收到终止信号时清理。
# DOWNLOAD_CACHE 指向 BuildKit 下载缓存时，已下载归档独立保留，方便失败后续传。
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
download_cache=${DOWNLOAD_CACHE:-$work_dir/downloads}
mkdir -p "$download_cache"

# download 下载URL 官方SHA256 临时目标文件
# 用 SHA-256 作为缓存名，切换下载镜像不会绕过内容校验，也不会混用其他版本。
download() {
    cached_archive="$download_cache/$2"
    if ! printf '%s  %s\n' "$2" "$cached_archive" | sha256sum --check --status >/dev/null 2>&1; then
        # 每次连接最多等待 20 秒，整个请求最多 1800 秒；失败后按已有字节断点续传。
        # 将 curl 放入 if，显式处理失败，避免 set -e 在首次临时网络错误时直接退出。
        for attempt in 1 2 3; do
            if curl --fail --silent --show-error --location --continue-at - \
                --connect-timeout 20 --max-time 1800 "$1" --output "$cached_archive"; then
                break
            fi
            echo "Download attempt $attempt failed; retaining partial archive for resume" >&2
        done
        if ! printf '%s  %s\n' "$2" "$cached_archive" | sha256sum --check --status; then
            # 所有重试结束后仍必须通过完整归档校验，失败时不安装、不回退旧版本。
            echo "Archive checksum verification failed: $1" >&2
            return 1
        fi
    fi
    # 安装流程只操作临时副本；下载缓存不随 work_dir 清理。
    cp "$cached_archive" "$3"
}

install_dart() {
# SDK 下载源可由构建参数切换，官方归档 SHA-256 保持不变。
download "${DART_DOWNLOAD_BASE_URL:-https://storage.googleapis.com}/dart-archive/channels/stable/release/$DART_VERSION/sdk/dartsdk-linux-x64-release.zip" \
    "$DART_SHA256" "$work_dir/dart.zip"
# 使用现有 Python ZIP 支持解压，避免额外安装 unzip。
python3 - "$work_dir/dart.zip" <<'PY'
import sys
import zipfile
from pathlib import Path

with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall('/opt')
    # zipfile 默认不会恢复 Unix 可执行权限，需按已校验归档的属性补回 Dart 等程序权限。
    for info in archive.infolist():
        mode = info.external_attr >> 16
        if mode:
            Path('/opt', info.filename).chmod(mode)
PY
# 固定 protoc_plugin 版本；全局激活会下载依赖、编译启动快照并生成 protoc-gen-dart 包装脚本。
dart pub global activate protoc_plugin "$DART_PROTOC_PLUGIN_VERSION"
# 兼容消费工程中原有的 /usr/bin/protoc-gen-dart 绝对路径。
ln -s /opt/dart-pub-cache/bin/protoc-gen-dart /usr/bin/protoc-gen-dart
# 输出实际 SDK 和已激活插件版本，便于在构建日志中核对。
dart --version
dart pub global list
}

install_jvm() {
# Java gRPC 生成器是原生可执行文件；Java 消息生成器本身由 protoc 内置。
download "https://repo.maven.apache.org/maven2/io/grpc/protoc-gen-grpc-java/$GRPC_JAVA_VERSION/protoc-gen-grpc-java-$GRPC_JAVA_VERSION-linux-x86_64.exe" \
    "$GRPC_JAVA_SHA256" "$work_dir/grpc-java"
install -m 0755 "$work_dir/grpc-java" /usr/bin/protoc-gen-grpc-java
# Kotlin gRPC 生成器以 JAR 发布，固定安装为不带版本号的路径，包装脚本无需随版本修改。
download "https://repo.maven.apache.org/maven2/io/grpc/protoc-gen-grpc-kotlin/$GRPC_KOTLIN_VERSION/protoc-gen-grpc-kotlin-$GRPC_KOTLIN_VERSION-jdk8.jar" \
    "$GRPC_KOTLIN_SHA256" "$work_dir/grpc-kotlin.jar"
install -m 0644 "$work_dir/grpc-kotlin.jar" /usr/bin/protoc-gen-grpc-kotlin.jar
# JAR 只需可读；protoc 实际执行的 Kotlin 包装脚本必须具有执行权限。
chmod 0755 /usr/bin/protoc-gen-grpc-kotlin.sh
}

install_web() {
# JS 官方归档提供原生 protoc-gen-js，无需再安装 npm 中的另一份插件，避免 PATH 混用。
# GitHub 资产前缀允许覆盖为下载镜像，归档仍使用 toolchain.env 中的官方 SHA-256。
download "${GITHUB_DOWNLOAD_BASE_URL:-https://github.com}/protocolbuffers/protobuf-javascript/releases/download/v$PROTOC_GEN_JS_VERSION/protobuf-javascript-$PROTOC_GEN_JS_VERSION-linux-x86_64.tar.gz" \
    "$PROTOC_GEN_JS_SHA256" "$work_dir/js.tar.gz"
tar -xzf "$work_dir/js.tar.gz" -C "$work_dir"
# 上游归档内的插件位于 bin/，安装到统一的 protoc 自动发现目录。
install -m 0755 "$work_dir/bin/protoc-gen-js" /usr/bin/protoc-gen-js
# 同一个官方 Web 插件负责 CommonJS gRPC-Web 和 TypeScript 客户端/类型声明。
download "${GITHUB_DOWNLOAD_BASE_URL:-https://github.com}/grpc/grpc-web/releases/download/$GRPC_WEB_VERSION/protoc-gen-grpc-web-$GRPC_WEB_VERSION-linux-x86_64" \
    "$GRPC_WEB_SHA256" "$work_dir/grpc-web"
install -m 0755 "$work_dir/grpc-web" /usr/bin/protoc-gen-grpc-web

# 直接执行一次，确认该平台二进制及其运行依赖可加载。
protoc-gen-grpc-web --version
}

# Dockerfile 分三次调用；保留 all 便于独立安装。未知分组直接报错，防止拼写错误被忽略。
case "${1:-all}" in
    dart) install_dart ;;
    jvm) install_jvm ;;
    web) install_web ;;
    all) install_dart; install_jvm; install_web ;;
    *) echo "Unknown plugin group: $1" >&2; exit 2 ;;
esac
