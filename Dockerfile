# 使用 BuildKit 多阶段构建：编译工具和源码留在构建阶段，只将插件交付到最终镜像。
# 所有组件版本、固定 Git 提交和下载 SHA-256 统一维护在 toolchain.env。
# 当前下载资产和插件面向 Linux x86_64，install-protoc.sh 会检查实际架构。

# 1. 公共运行环境：后续构建阶段和最终镜像均从这个基础环境继承。
FROM ubuntu:26.04 AS base

# 镜像维护者信息，不参与 protoc 或插件的版本选择。
LABEL maintainer="Hetao<hetao@hetao.name>"

# 禁止 APT 在构建过程中交互询问时区等配置，保证无人值守构建可以完成。
ENV DEBIAN_FRONTEND=noninteractive

# ca-certificates/curl：通过 HTTPS 下载并验证上游归档。
# python3：解压 protoc/Dart ZIP，并执行生成结果的语法与 JSON 检查。
# default-jre-headless：运行 Kotlin gRPC 生成器的 JAR，无需桌面环境。
# libstdc++6：运行 C++ 编写的 protoc 和原生插件所需的标准库。
# 不安装推荐包，并在同一层清理 APT 索引，减少镜像体积。
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 default-jre-headless libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 将固定版本配置放入镜像，供安装脚本读取，也便于通过 make versions 查看。
COPY toolchain.env /opt/docker-protoc/toolchain.env

# 安装上游 protoc：校验 SHA-256，同时安装同版本标准 .proto includes。
# 脚本将编译器放到 /usr/local/bin，标准协议放到 /usr/local/include。
COPY bin/install-protoc.sh /usr/local/bin/install-protoc.sh

# protoc、JS、Web 归档默认来自 GitHub release；网络受限时可覆盖下载前缀，SHA-256 校验不变。
ARG GITHUB_DOWNLOAD_BASE_URL=https://github.com

# set -a 将配置里的版本/校验值导出给子进程；安装失败会使该 RUN 失败。
# 安装脚本会核对绝对路径和 PATH 实际调用的 protoc 版本，防止误用旧编译器。
# 归档缓存保留已下载内容，版本配置更新后也可复用相同 SHA-256 的编译器下载。
RUN --mount=type=cache,id=docker-protoc-downloads,target=/var/cache/docker-protoc/downloads,sharing=locked \
    set -a; . /opt/docker-protoc/toolchain.env; \
    DOWNLOAD_CACHE=/var/cache/docker-protoc/downloads GITHUB_DOWNLOAD_BASE_URL=${GITHUB_DOWNLOAD_BASE_URL} \
    /bin/sh /usr/local/bin/install-protoc.sh

# 2. 原生 gRPC 插件构建阶段：从锁定的最新稳定源码构建 C++/PHP/Python/Ruby 插件。
# 不使用 Ubuntu 的旧版 protobuf-compiler-grpc，最终镜像也不继承本阶段的编译环境。
FROM base AS grpc-build

# build-essential/cmake/ninja-build：配置并编译 gRPC 原生插件。
# 源码通过 GitHub 官方 codeload 获取，逐一校验固定提交归档的 SHA-256，无需 git clone。
# pkg-config 和开发库：满足上游 CMake 配置要求；不把这些开发包复制到最终镜像。
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build pkg-config libssl-dev libc-ares-dev libre2-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# 脚本校验 gRPC 和构建依赖的源码归档，仅构建四个插件，将剥离调试符号的二进制放到 /opt/plugins。
COPY bin/build-grpc-plugins.sh /usr/local/bin/build-grpc-plugins.sh

# libprotoc 只用于 gRPC 插件协议和描述符处理；消息生成直接使用官方 protoc。
# 配置钩子保留通用 compiler/命名代码，跳过重复的各语言消息后端编译。
COPY cmake/grpc-plugin-bridge.cmake /opt/docker-protoc/grpc-plugin-bridge.cmake

# C++ 编译并发数；内存较少时使用 --build-arg BUILD_JOBS=1。
# 参数放在开发依赖安装之后，调整并发不会使 APT 安装层重新下载。
ARG BUILD_JOBS=2

# 缓存源码、依赖归档和 CMake/Ninja 产物，下载或构建中断后可以复用。
# sharing=locked 防止并发构建同时修改同一缓存；cache mount 不进入最终镜像层。
RUN --mount=type=cache,id=docker-protoc-grpc,target=/var/cache/docker-protoc/grpc,sharing=locked \
    BUILD_JOBS=${BUILD_JOBS} /bin/sh /usr/local/bin/build-grpc-plugins.sh

# 3. Go 实现的生成器构建阶段，与原生 gRPC 构建阶段相互独立。
FROM base AS go-build

# Go 编译器和 git 只用于构建生成器，不复制到最终运行镜像。
RUN apt-get update && apt-get install -y --no-install-recommends golang-go git \
    && rm -rf /var/lib/apt/lists/*

# GOPROXY：沿用中国区模块代理，并允许直接访问上游作为后备。
# GOBIN：集中收集待交付插件；CGO_ENABLED=0：避免引入额外 C 动态库依赖。
# GOFLAGS=-p=2：限制编译并发，减少与 C++/Dart 同时构建时的内存占用。
ENV GOPROXY=https://goproxy.cn,direct GOBIN=/opt/plugins CGO_ENABLED=0 GOFLAGS=-p=2

# 构建固定版本的 Go 消息/gRPC、gateway、OpenAPI、文档和 PHP 服务端接口插件。
COPY bin/build-go-plugins.sh /usr/local/bin/build-go-plugins.sh

# 分别缓存下载的 Go 模块和编译产物，重试时无需重新下载、编译全部依赖。
RUN --mount=type=cache,target=/root/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/root/.cache/go-build,sharing=locked \
    /bin/sh /usr/local/bin/build-go-plugins.sh

# 4. 安装 Dart、Java/Kotlin、JavaScript 与 gRPC-Web/TypeScript 生成器。
# 每组安装使用独立 RUN：例如 Web 下载失败时，不需要再次编译已安装的 Dart 插件。
FROM base AS language-plugins

# Dart SDK 默认从 Google 官方归档下载；可覆盖为 Flutter 中国镜像，SHA-256 校验不变。
ARG DART_DOWNLOAD_BASE_URL=https://storage.googleapis.com

# JS/Web 插件默认从 GitHub release 下载；可覆盖资产镜像前缀，仍按官方 SHA-256 校验。
ARG GITHUB_DOWNLOAD_BASE_URL=https://github.com

# 公共安装脚本根据 dart/jvm/web 参数选择组件组，下载版本从 toolchain.env 读取。
COPY bin/install-language-plugins.sh /usr/local/bin/install-language-plugins.sh

# Kotlin 插件是 JAR，使用该包装脚本接入 protoc 的可执行插件接口。
COPY bin/protoc-gen-grpc-kotlin.sh /usr/bin/protoc-gen-grpc-kotlin.sh

# Dart SDK 与全局插件采用固定安装目录；最终生成 Dart 代码时仍需要这些运行文件。
ENV PATH=/opt/dart-sdk/bin:/opt/dart-pub-cache/bin:${PATH} \
    PUB_CACHE=/opt/dart-pub-cache

# 下载并校验 Dart SDK，恢复 ZIP 中的执行权限，再激活固定版本 protoc_plugin。
# 下载缓存以 SHA-256 命名，支持校验复用与断点续传；临时解压文件会在脚本退出时清理。
RUN --mount=type=cache,id=docker-protoc-downloads,target=/var/cache/docker-protoc/downloads,sharing=locked \
    DOWNLOAD_CACHE=/var/cache/docker-protoc/downloads DART_DOWNLOAD_BASE_URL=${DART_DOWNLOAD_BASE_URL} \
    /bin/sh /usr/local/bin/install-language-plugins.sh dart

# 从 Maven Central 下载并校验 Java gRPC 原生生成器和 Kotlin gRPC JAR。
# Java/Kotlin 的消息生成器由 protoc 内置，此处安装各自独立发布的 gRPC 插件。
RUN --mount=type=cache,id=docker-protoc-downloads,target=/var/cache/docker-protoc/downloads,sharing=locked \
    DOWNLOAD_CACHE=/var/cache/docker-protoc/downloads \
    /bin/sh /usr/local/bin/install-language-plugins.sh jvm

# 安装官方 protoc-gen-js 和 protoc-gen-grpc-web，替代仓库中的旧二进制。
# TypeScript 复用 gRPC-Web 插件，生成 TS 客户端和消息 .d.ts；消息实现由 JS 插件生成。
# 代码生成不需要 Node.js，消费工程自行提供 JS/TS 编译器和运行库。
RUN --mount=type=cache,id=docker-protoc-downloads,target=/var/cache/docker-protoc/downloads,sharing=locked \
    DOWNLOAD_CACHE=/var/cache/docker-protoc/downloads GITHUB_DOWNLOAD_BASE_URL=${GITHUB_DOWNLOAD_BASE_URL} \
    /bin/sh /usr/local/bin/install-language-plugins.sh web

# 5. 合并工具链：仅复制两个编译阶段的插件，不复制源码、Go/C++ 编译器和开发库。
FROM language-plugins AS toolchain

# 保持 /usr/bin/grpc_*_plugin 等历史绝对路径，兼容现有消费工程的 --plugin 参数。
COPY --from=grpc-build /opt/plugins/ /usr/bin/

# Go 消息/gRPC、gateway、OpenAPI、文档和 PHP 服务端插件统一进入 PATH。
COPY --from=go-build /opt/plugins/ /usr/bin/

# 6. 生成验证阶段，也是默认最终镜像；任一生成检查失败都会阻止构建成功。
FROM toolchain AS verified

# 复制最小示例和回归协议；验证时由当前工具链生成新的结果。
COPY test/proto/ /opt/docker-protoc/test/proto/
COPY test/fixtures/ /opt/docker-protoc/test/fixtures/

# 保留统一生成和验证入口，方便容器启动后通过 make all / make test 再次使用。
COPY bin/generate.sh bin/smoke-test.sh /usr/local/bin/

# 在临时目录实际运行全部语言、TypeScript、OpenAPI 和文档生成，并检查关键产物。
# 检查结束后清理临时结果，不改写宿主机样例；消费工程仍需验证其运行库和业务行为。
RUN /bin/sh /usr/local/bin/smoke-test.sh
