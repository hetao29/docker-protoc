# 项目指南

适用于整个仓库。依据当前工作区的源码和构建文件维护；修改工具链时同步更新本指南、
`README.md` 和 `toolchain.env`，版本与校验值以 `toolchain.env` 为准。

## 功能与架构

本项目将 protoc、多语言 protobuf/gRPC 生成器及协议文档插件封装为 Docker 镜像，
镜像仓库为 `hetao29/docker-protoc`，当前支持 Linux x86_64。
支持 Go、PHP、Dart、C++、JavaScript、gRPC-Web、TypeScript、Python、Ruby、Java、Kotlin，
另提供 OpenAPI v2、Markdown 和 HTML 输出。项目没有业务服务和数据库。

```text
宿主机 .proto
  -> docker run（挂载工程并设置工作目录）
  -> protoc（解析协议/import，读取同版本标准 includes）
  -> 内置消息生成器 + protoc-gen-* / grpc_*_plugin
  -> 将源码/文档写回挂载目录
  -> 消费工程安装配套运行库、编译、验证和部署
```

默认 Dockerfile 使用 Ubuntu 26.04，多阶段构建：

1. `base`：安装运行依赖和固定版本 protoc。
2. `grpc-build`：从固定 gRPC tag/commit 构建 C++、PHP、Python、Ruby gRPC 插件。
   使用该 gRPC 提交记录的 protobuf/Abseil 构建依赖；这些内部依赖不替换最终 protoc。
3. `go-build`：构建固定版本 Go 消息/gRPC、gateway、OpenAPI、文档和 PHP 服务端插件。
4. `language-plugins`：安装 Dart SDK/插件、Java/Kotlin、JS、Web 插件，可独立验证这些语言。
5. `toolchain`：合并各阶段的插件二进制。
6. `verified`：运行所有语言生成验证；此阶段为最终镜像。

最终镜像保留 Dart SDK、Python 和 Java 运行环境供插件使用；不携带构建阶段的 Go/C++
编译环境与源码。业务工程的语言运行库由业务工程管理。默认 Dockerfile 未设置 ENTRYPOINT，
可以直接运行 `docker run ... IMAGE protoc ...`。

## 文件职责

| 路径 | 职责 |
| --- | --- |
| `toolchain.env` | 固定稳定版本、Git 提交及下载 SHA-256；所有安装阶段的唯一版本配置 |
| `Dockerfile` | 完整构建全部新工具链，并执行生成检查 |
| `bin/install-protoc.sh` | 校验下载、安装 protoc 和同版本标准 includes，检查 PATH 实际版本 |
| `bin/build-grpc-plugins.sh` | 下载校验固定提交的 gRPC/依赖源码归档，构建四种 gRPC 插件 |
| `cmake/grpc-plugin-bridge.cmake` | 仅保留 gRPC 使用的 libprotoc 通用代码和命名辅助，消息后端由官方 protoc 提供 |
| `bin/build-go-plugins.sh` | 安装固定版本的 Go 实现插件 |
| `bin/install-language-plugins.sh` | 校验安装 Dart、Java、Kotlin、JS、Web 下载产物 |
| `bin/protoc-gen-grpc-kotlin.sh` | 启动 `/usr/bin/protoc-gen-grpc-kotlin.jar`，转发参数 |
| `bin/generate.sh` | 统一多语言与文档生成入口，供 Makefile 和构建检查复用 |
| `bin/smoke-test.sh` | 在临时目录运行所有生成器，检查关键产物、OpenAPI、Python 语法 |
| `Makefile` | 构建、验证、生成示例、查看版本及发布命令 |
| `test/proto/helloworld.proto` | Greeter.SayHello、HelloRequest/HelloReply、proto3 optional 示例 |
| `test/fixtures/` | 兼容性回归协议，包括 PHP public dependency 索引样例 |
| `test/php-runtime.php` | 使用消费端 protobuf autoloader 检查 optional/public dependency 序列化 |
| `test/typescript/` | TS 7.0.2 类型检查与 JS 二进制往返测试，包含依赖锁文件 |
| `test/out/`、`test/docs/` | 当前工具链的生成输出目录 |
| `.dockerignore` | 排除 Git、本机配置和历史生成产物，避免扩大构建上下文 |

生成插件从锁定的上游来源下载或编译。

## 版本与兼容性

2026-11-16 核对的稳定版：protoc 36.2；gRPC 1.84.3；Go protobuf v1.36.12；
Go gRPC v1.6.2；gateway/OpenAPI v2.33.0；文档插件 v1.5.1；Dart SDK 3.14.0 / 插件 25.1.0；
Java gRPC 1.85.1；Kotlin gRPC 1.5.0；JS 4.0.3；gRPC-Web/TypeScript 2.1.1。
PHP 服务端插件从上游提交 `4519f359a51edcbdb0294f2d5325e363800daab3` 构建。
各版本的官方来源链接见 README；后续更新需重新核对官方稳定发行。

- “最新”按已发布的稳定版本解释；不自动引入 RC、nightly 或 Maven 的不透明快照版本。
  当前 protobuf 37.0-rc2 不纳入稳定升级。
- protoc 同时更新内置消息生成器；各语言的 gRPC 插件拥有独立版本号。
- `install-protoc.sh` 拒绝非 x86_64，将编译器安装到 `/usr/local/bin/protoc`，
  标准 includes 安装到 `/usr/local/include`，版本记录到 `/usr/local/share/docker-protoc/`。
- protoc、Dart SDK、Java/Kotlin、JS、Web 下载均校验 SHA-256；Go 模块使用固定版本和校验机制。
  改版本时同步更新校验值，不绕过校验或回退到系统旧编译器。
- TypeScript 使用官方 gRPC-Web 插件：输出 JS 消息实现、消息 `.d.ts`、TS 客户端。
  不向 `--js_out` 传入 `import_style=typescript`。消费端自行安装 TS 编译器及运行库。
- Dart 插件 25.1.0 要求消费端 protobuf 包至少为 6.1.0。
- PHP public/weak 依赖索引修复依靠上游 protoc；不手改业务字段编号、删除 `import public`
  或在运行时替换元数据。PHP 运行库和扩展需要与生成代码配套，原有验证版本为 5.36.2。
- 升级后使消费工程的增量生成缓存失效，再完整重新生成。尤其 C++ 的编译器/运行库兼容性
  不能只靠成功生成来判断；所有语言均需消费工程的实际编译和运行时验证。

## 命令与输出

Makefile 默认 `DOCKER=sudo docker`、`IMAGE=hetao29/docker-protoc:latest`；可显式覆盖。
全部操作目标已声明 `.PHONY`。普通 `make` 等同于 `make test`，执行实际生成验证。

```bash
make build IMAGE=hetao29/docker-protoc:36.2
make test IMAGE=hetao29/docker-protoc:36.2
make versions IMAGE=hetao29/docker-protoc:36.2
make all IMAGE=hetao29/docker-protoc:36.2
make typescript IMAGE=hetao29/docker-protoc:36.2
make -n php
```

- `all` 执行所有语言和文档目标；语言输出在 `test/out/<目标>/`，目录自动创建。
- `go` 包含 `--go_out`、gRPC、gateway 和 OpenAPI；示例为未注解 RPC 开启 HTTP 映射。
- `php` 生成消息、客户端和服务端接口；第二次仅运行服务端插件。
- `js` 输出 CommonJS 二进制消息；`web` 输出 CommonJS/grpcwebtext 客户端；
  `typescript`（别名 `ts`）输出 gRPC-Web TS 客户端与消息类型声明。
- `python` 同时输出 `.pyi`；`kotlin` 同时输出 Java 消息、Kotlin DSL、Java/Kotlin gRPC。
- `doc` 将所有输入协议合并到 `test/docs/md/index.md` 和 `test/docs/html/index.html`。
- `push` 只推送 `IMAGE`；`push-tag` 标记并推送 `REPOSITORY:VERSION`。
  不使用旧版本标签表示新工具链，不把构建验证等同于发布。

## 验证与维护

- 修改前检查 `git status`，保留已有修改与未跟踪文件，不覆盖用户未提交工作。
- Shell 改动先运行 `sh -n bin/*.sh`（逐个文件检查）；文档/源码使用 `git diff --check`。
- 构建执行 `smoke-test.sh`，通过运行生成器检查实际依赖加载和关键产物，不能仅检查文件存在于旧样例目录。
- 原生 gRPC 的私有 libprotoc 裁剪通过 CMake 延迟钩子实现；仅构建四个插件目标，
  不在该构建目录编译完整上游 protoc。新增依赖命名辅助时须核对链接和 proto2/流式 RPC 回归。
- `make test` 重新运行同一套生成检查，使用临时目录并自动清理，不修改宿主机生成文件。
- Go/C++ 构建阶段耗时较长；内存少时用 `--build-arg BUILD_JOBS=1` 限制 C++ 并发。
- Go 编译、gRPC 源码/构建和下载使用 BuildKit cache mount，构建中断可复用缓存。
  Dart 下载源可通过 `DART_DOWNLOAD_BASE_URL` 构建参数覆盖，仍必须通过官方 SHA-256 校验。
  `GITHUB_DOWNLOAD_BASE_URL` 可覆盖 protoc/JS/Web release 资产前缀；源码固定提交来自 GitHub codeload。
- 验证指定镜像时显式传递 `IMAGE`，避免误用旧 `latest`。
- 历史生成文件不能代替当前工具链的实际生成验证。
  修复生成逻辑应修改生成器、协议或参数，再重新生成并审阅差异，不手改生成文件掩盖问题。
- 没有业务服务的端到端测试。发布前另在消费工程检查各语言依赖、编译及 PHP 纯 PHP/C 扩展运行。
- `test/php-runtime.php` 接受生成 PHP 目录、protobuf autoloader 路径和 public fixture 输出目录；
  分别用正常 PHP 与 `php -n`（无 protobuf 扩展）执行。不要改动宿主机已安装依赖来迁就测试。
- TypeScript 验证在临时目录复制 `test/typescript/`，将生成的 TS/JS 放入其 `generated/`，
  使用现代 Node.js 执行 `npm ci` 和 `npm test`；不要将 node_modules 放入仓库或镜像。
- 新增语言目标时同步更新 `generate.sh`、Makefile、smoke-test 及文档。
- 本地 Git 配置 `pull.rebase=true`、`rebase.autoStash=true`、`pull.ff=only` 位于 `.git/config`，
  不随克隆传播；自动暂存恢复可能冲突，遇到时保留并处理改动。
