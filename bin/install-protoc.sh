#!/bin/sh
# 安装固定版本的上游 protoc 及同版本标准 includes，供 Docker 公共 base 阶段调用。
# 必填环境变量：PROTOC_VERSION、PROTOC_SHA256；由 Dockerfile 从 toolchain.env 导出。
# 可选环境变量：DOWNLOAD_CACHE（归档缓存）、GITHUB_DOWNLOAD_BASE_URL（release 下载前缀）。
set -eu

# 未提供版本或校验值时立即失败，不使用动态 latest，也不回退到系统旧编译器。
: "${PROTOC_VERSION:?Set the official protoc release version}"
: "${PROTOC_SHA256:?Set the SHA-256 of the linux-x86_64 release archive}"
# 本项目锁定 linux-x86_64 归档，其他架构需要另行准备匹配资产和校验值。
if [ "$(uname -m)" != x86_64 ]; then
    echo 'This image currently supports linux-x86_64 only' >&2
    exit 1
fi

# 解压使用独立临时目录；信号/正常退出均清理。外部下载缓存不在该目录内时会保留。
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
download_cache=${DOWNLOAD_CACHE:-$work_dir}
mkdir -p "$download_cache"
archive="$download_cache/$PROTOC_SHA256.zip"
# 每次先验证缓存，完整且匹配时跳过网络；未完成的下载保留以便 curl 继续。
if ! printf '%s  %s\n' "$PROTOC_SHA256" "$archive" | sha256sum --check --status >/dev/null 2>&1; then
    for attempt in 1 2 3; do
        # 最多重试三次，每次最长 300 秒、连接最长 20 秒；HTTPS 重定向仍需通过最终 SHA 校验。
        if curl --fail --silent --show-error --location --continue-at - --connect-timeout 20 --max-time 300 \
            "${GITHUB_DOWNLOAD_BASE_URL:-https://github.com}/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" \
            --output "$archive"; then
            break
        fi
        echo "protoc download attempt $attempt failed; retaining partial archive" >&2
    done
    # 在解压和覆盖安装之前检查完整归档；失败由 set -e 传播给 docker build。
    printf '%s  %s\n' "$PROTOC_SHA256" "$archive" | sha256sum --check --status
fi
# Python 仅解压已经通过校验的发布归档，不执行归档内的安装脚本。
python3 - "$archive" "$work_dir" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall(sys.argv[2])
PY
# /usr/local/bin 在常见 PATH 中优先于 /usr/bin；显式恢复可执行权限。
install -m 0755 "$work_dir/bin/protoc" /usr/local/bin/protoc
install -d /usr/local/include /usr/local/share/docker-protoc
# 标准 .proto 必须与编译器同步更新，避免使用旧版 google/protobuf 定义。
cp -R "$work_dir/include/." /usr/local/include/
# 记录实际安装的发布版本和归档校验值，方便对已构建镜像追溯。
printf '%s\n' "$PROTOC_VERSION" > /usr/local/share/docker-protoc/protoc.version
printf '%s\n' "$PROTOC_SHA256" > /usr/local/share/docker-protoc/protoc.sha256
# 同时检查指定二进制和普通命令查找结果，发现 PATH 被其他 protoc 遮蔽时立即失败。
test "$(/usr/local/bin/protoc --version)" = "libprotoc $PROTOC_VERSION"
test "$(protoc --version)" = "libprotoc $PROTOC_VERSION"
# 成功时向构建日志打印实际版本。
protoc --version
