# Docker protoc 多语言生成工具链

将 protoc 和各语言的 protobuf/gRPC 生成器打包到一个 Linux x86_64 镜像。
支持 Go、PHP、Dart、C++、JavaScript、gRPC-Web、TypeScript、Python、Ruby、Java、Kotlin，
以及 OpenAPI v2、Markdown 和 HTML 文档生成。

## 稳定版本

以下为 **2026-11-16 核对的最新稳定版本**，统一锁定在 `toolchain.env`。
构建不会自动追随 `latest`、RC 或开发快照；升级时更新版本及归档校验值。

| 组件 / 语言 | 版本 | 官方来源 |
| --- | --- | --- |
| protoc；内置 C++、PHP、Python、Ruby、Java、Kotlin 等消息生成器 | 36.2 | [protobuf releases](https://github.com/protocolbuffers/protobuf/releases) |
| C++ / PHP 客户端 / Python / Ruby gRPC 插件 | 1.84.3 | [gRPC release](https://github.com/grpc/grpc/releases/tag/v1.84.3) |
| Go 消息生成器 | v1.36.12 | [protobuf-go](https://github.com/protocolbuffers/protobuf-go/releases) |
| Go gRPC 生成器 | v1.6.2 | [grpc-go](https://github.com/grpc/grpc-go/releases) |
| Go gateway / OpenAPI v2 | v2.33.0 | [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway/releases) |
| Dart SDK / protoc_plugin | 3.14.0 / 25.1.0 | [SDK](https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION)、[插件](https://pub.dev/packages/protoc_plugin/changelog) |
| Java gRPC 插件 | 1.85.1 | [Maven metadata](https://repo.maven.apache.org/maven2/io/grpc/protoc-gen-grpc-java/maven-metadata.xml) |
| Kotlin gRPC 插件 | 1.5.0 | [Maven metadata](https://repo.maven.apache.org/maven2/io/grpc/protoc-gen-grpc-kotlin/maven-metadata.xml) |
| JavaScript protoc-gen-js | 4.0.3 | [protobuf-javascript](https://github.com/protocolbuffers/protobuf-javascript/releases/tag/v4.0.3) |
| gRPC-Web / TypeScript 生成器 | 2.1.1 | [grpc-web](https://github.com/grpc/grpc-web/releases/tag/2.1.1) |
| PHP 服务端接口插件 | 上游提交 `4519f359a51edcbdb0294f2d5325e363800daab3` | [源码](https://github.com/hetao29/php-grpc-server-protobuf-plugin/tree/4519f359a51edcbdb0294f2d5325e363800daab3) |
| Markdown / HTML 文档插件 | v1.5.1 | [protoc-gen-doc](https://github.com/pseudomuto/protoc-gen-doc/releases) |

protoc 36.2 已是最新稳定版；37.0-rc2 是预发布版。PHP 服务端插件没有新的稳定发行，
因此从当前上游提交重新编译，保留原有服务端接口生成方式。
Java/Kotlin 的消息生成器随 protoc 更新，gRPC 插件另行更新。

## 构建与验证

需要 Docker 和网络访问。完整构建使用多个阶段分别编译 gRPC 和 Go 插件，
最终镜像不携带这些阶段的编译器、源码和构建缓存。gRPC 的四个插件从固定上游提交构建，
不再依赖 Ubuntu 提供的旧版 `protobuf-compiler-grpc`。
消息生成统一使用官方 protoc；构建期间的 `libprotoc` 仅保留 gRPC 插件协议、描述符处理和
命名辅助代码，通过 CMake 钩子裁剪重复的消息后端。四个原生插件另有 proto2、嵌套消息和
客户端/服务端/双向流的生成回归用例。
下载的 protoc、Dart SDK、Java/Kotlin 插件、JS/Web 插件及 gRPC/构建依赖源码均检查 SHA-256。

```bash
make build IMAGE=hetao29/docker-protoc:36.2
make versions IMAGE=hetao29/docker-protoc:36.2
make test IMAGE=hetao29/docker-protoc:36.2
```

构建最后会实际生成所有语言、TypeScript 声明、OpenAPI 和文档，检查关键产物，
并生成含 `import public` 的 PHP 回归样例。`make test` 可单独重跑这些检查，
不会改写宿主机的生成样例。生成成功不等于消费工程的编译和运行时验证通过。
资源较少时可直接构建并限制 C++ 编译并发：

```bash
sudo docker build --build-arg BUILD_JOBS=1 -t hetao29/docker-protoc:36.2 .
```

Dart SDK 默认从 Google 官方归档下载。网络受限时可添加
`--build-arg DART_DOWNLOAD_BASE_URL=https://storage.flutter-io.cn` 使用 Flutter 中国镜像；
无论下载源如何，均校验同一个官方 SHA-256。下载支持断点续传，Go/C++ 构建和下载缓存
存放在 BuildKit cache mount 中，不进入最终镜像。
GitHub release 归档的下载前缀还可通过 `GITHUB_DOWNLOAD_BASE_URL` 覆盖，
供网络受限时使用资产镜像；protoc、JS 和 Web 归档仍必须通过官方 SHA-256 校验。

## 生成示例

协议源文件位于 `test/proto/`，包含 `Greeter.SayHello` 和 proto3 optional 字段。
每个目标会自动建立输出目录，`DOCKER` 和 `IMAGE` 可以覆盖：

```bash
make all IMAGE=hetao29/docker-protoc:36.2
make php IMAGE=hetao29/docker-protoc:36.2
make dart java js typescript IMAGE=hetao29/docker-protoc:36.2
# 已有 Docker 权限时可不使用 sudo
make typescript DOCKER=docker IMAGE=hetao29/docker-protoc:36.2
```

| 目标 | 输出 |
| --- | --- |
| `go` | Go 消息类、gRPC、gateway 和 OpenAPI v2；gateway 示例为未注解 RPC 生成 HTTP 映射 |
| `php` | PHP 消息类、gRPC 客户端、PHP 服务端接口 |
| `dart`、`cpp`、`java`、`ruby` | 对应语言的消息类型与 gRPC 代码 |
| `python` | 消息类型、`.pyi` 类型声明与 gRPC 代码 |
| `kotlin` | Java 消息类型、Kotlin 消息 DSL、Java gRPC 和 Kotlin gRPC 代码 |
| `js` | CommonJS 消息代码，启用二进制序列化 |
| `web` | CommonJS 消息和 grpcwebtext 客户端 |
| `typescript`（别名 `ts`） | JS 消息代码、消息 `.d.ts` 声明、TypeScript gRPC-Web 客户端 |
| `doc` | 所有输入协议的合并文档：`test/docs/md/index.md` 与 `test/docs/html/index.html` |
| `all` | 上述所有目标 |

语言代码写入 `test/out/<目标>/`。修改生成器或协议后，请重新生成并审阅输出差异。

TypeScript 使用官方 gRPC-Web 方案；消息实现仍是 JS，类型由 `.d.ts` 提供。
消费工程需要 `google-protobuf`（当前 4.0.3）、`grpc-web`（当前 2.1.1），以及
`@types/google-protobuf`。TypeScript 编译器由消费工程安装，生成镜像无需 Node.js。
Dart protoc_plugin 25.1.0 要求消费工程的 `protobuf` 包至少为 6.1.0。

`test/typescript/` 提供锁定 TypeScript 7.0.2 的类型检查和 JS 序列化测试。
验证时在临时目录复制该测试目录，将 `test/out/typescript/` 的生成文件放到其
`generated/` 子目录，再使用现代 Node.js 执行 `npm ci`、`npm test`。
`test/php-runtime.php` 可用消费工程的 protobuf autoloader 验证 optional 和 public 依赖：

```bash
php test/php-runtime.php test/out/php /path/to/vendor/autoload.php /path/to/generated-public-fixture
php -n test/php-runtime.php test/out/php /path/to/vendor/autoload.php /path/to/generated-public-fixture
```

## 在业务工程中使用

容器挂载工程目录并设置工作目录，将生成文件直接写回宿主机。例如生成 PHP 客户端：

```bash
mkdir -p proto_generated
sudo docker run --rm -v "$PWD:$PWD" -w "$PWD" hetao29/docker-protoc:36.2 protoc \
  -I proto/ -I . --php_out=proto_generated --grpc_out=proto_generated \
  --plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin proto/helloworld.proto
```

PHP 服务端接口生成时，将插件路径替换为 `/usr/bin/protoc-gen-php-grpc`。

旧编译器生成 PHP 元数据时可能调整依赖列表却保留原 public/weak 索引，导致 PHP C 扩展报
`public_dep ... is out of range`。当前使用上游 protoc 36.2，不需要修改业务字段、编号、
`import public` 或运行时元数据。此前验证使用的 PHP 运行库和 C 扩展为 5.36.2。

工具链升级后应使消费工程的增量生成缓存失效，再完整重新生成，并验证各语言运行库兼容性。
尤其 C++、Java、Dart、Python 等消费端需要配套运行库；本镜像不替消费工程升级依赖。
部署使用经过验证的固定标签，并记录镜像 digest。

## 发布

`make push` 只推送 `IMAGE` 指定的标签；`make push-tag` 将该镜像标记为 `VERSION` 并推送。
运行这些目标前核对目标仓库和标签，不要将新工具链重新发布为旧版本标签。

```bash
make push-tag IMAGE=hetao29/docker-protoc:36.2 VERSION=36.2
```
