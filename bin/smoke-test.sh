#!/bin/sh
# 镜像内生成验证入口，既在 Dockerfile 最后执行，也供 make test 单独重跑。
# 检查工具链能运行并生成预期产物；消费端语言运行库、TS 类型检查和业务运行另行验证。
set -eu
. /opt/docker-protoc/toolchain.env
# 精确检查 PATH 中的编译器与 Go 插件，避免旧镜像或其他同名二进制混入。
# Go gRPC 的 --version 输出不带 v，需去掉锁文件版本值的 v 前缀后比较。
test "$(protoc --version)" = "libprotoc $PROTOC_VERSION"
test "$(protoc-gen-go --version)" = "protoc-gen-go $GO_PROTOBUF_VERSION"
test "$(protoc-gen-go-grpc --version)" = "protoc-gen-go-grpc ${GO_GRPC_VERSION#v}"
test "$(protoc-gen-php-grpc --version)" = "php-grpc-server-protobuf-plugin ${PHP_GRPC_SERVER_VERSION#v}"

# 全部输出写入容器临时目录，退出时自动清理，不依赖宿主机已有生成文件。
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
# 语言代码和合并文档分开生成，复用与 Makefile 相同的参数入口。
/bin/sh /usr/local/bin/generate.sh all /opt/docker-protoc/test/proto "$work_dir/out"
/bin/sh /usr/local/bin/generate.sh doc /opt/docker-protoc/test/proto "$work_dir"
# 核对消息、服务、类型声明、gateway/OpenAPI 和文档均已实际生成，且文件非空。
# 例如 Go 必须有消息文件，Kotlin 必须带 Java gRPC，TS 必须包含消息声明和客户端。
for artifact in \
    out/go/github.com/hetao29/test/helloworld.pb.go \
    out/go/github.com/hetao29/test/helloworld_grpc.pb.go \
    out/go/github.com/hetao29/test/helloworld.pb.gw.go \
    out/go/helloworld.swagger.json \
    out/php/Test/HelloRequest.php out/php/Test/GreeterClient.php out/php/Test/GreeterInterface.php \
    out/dart/helloworld.pb.dart out/dart/helloworld.pbgrpc.dart \
    out/cpp/helloworld.pb.cc out/cpp/helloworld.grpc.pb.cc \
    out/js/helloworld_pb.js out/web/helloworld_grpc_web_pb.js \
    out/typescript/helloworld_pb.d.ts out/typescript/HelloworldServiceClientPb.ts \
    out/python/helloworld_pb2.py out/python/helloworld_pb2.pyi out/python/helloworld_pb2_grpc.py \
    out/ruby/helloworld_pb.rb out/ruby/helloworld_services_pb.rb \
    out/java/test/Helloworld.java out/java/test/GreeterGrpc.java \
    out/kotlin/test/Helloworld.java out/kotlin/test/GreeterGrpc.java \
    out/kotlin/test/HelloRequestKt.kt out/kotlin/test/HelloworldGrpcKt.kt \
    docs/md/index.md docs/html/index.html; do
    test -s "$work_dir/$artifact" || { echo "Missing generated artifact: $artifact" >&2; exit 1; }
done
# 生成 descriptor.proto + import public 的 PHP 回归样例，覆盖依赖过滤后的元数据生成路径。
# 真正的 PHP 加载/序列化测试由 test/php-runtime.php 在配套运行库环境中执行。
mkdir -p "$work_dir/compatibility"
protoc -I /opt/docker-protoc/test/fixtures -I /usr/local/include \
    --php_out="$work_dir/compatibility" public-dependency.proto
# 只做生成 Python 文件的语法检查，不在此加载消费端 protobuf/grpc 运行库。
python3 -m compileall -q "$work_dir/out/python"
# 单独覆盖四个原生插件的 proto2、嵌套消息、客户端/服务端/双向流代码路径。
# 这些用例验证桥接库裁剪后仍能处理完整的 gRPC 插件请求。
for language in cpp php python ruby; do
    mkdir -p "$work_dir/streaming/$language"
    protoc -I /opt/docker-protoc/test/fixtures -I /usr/local/include \
        --plugin="protoc-gen-grpc=/usr/bin/grpc_${language}_plugin" \
        --grpc_out="$work_dir/streaming/$language" streaming.proto
done
test -s "$work_dir/streaming/cpp/streaming.grpc.pb.cc"
test -s "$work_dir/streaming/php/Compatibility/StreamingClient.php"
test -s "$work_dir/streaming/python/streaming_pb2_grpc.py"
test -s "$work_dir/streaming/ruby/streaming_services_pb.rb"
# PHP 服务端接口另行验证四类 RPC；官方原生 PHP 插件只生成客户端。
mkdir -p "$work_dir/streaming/php-server"
protoc -I /opt/docker-protoc/test/fixtures -I /usr/local/include \
    --php-grpc_out="$work_dir/streaming/php-server" streaming.proto
python3 - "$work_dir/streaming/php-server/Compatibility/StreamingInterface.php" <<'PY'
import pathlib
import re
import sys
source = pathlib.Path(sys.argv[1]).read_text()
assert re.search(r'public function Unary\([^)]*\$request\): StreamReply;', source), source
for signature in (
    'public function Upload(\\GRpcStream $request): StreamReply;',
    'public function Download(StreamRequest $request): iterable;',
    'public function Chat(\\GRpcStream $request): iterable;',
):
    assert signature in source, signature
assert 'iterable<StreamReply>' in source, source
PY
# 验证 OpenAPI 不是空 JSON：未注解的示例 RPC 应拥有对应 HTTP 路径。
python3 - "$work_dir/out/go/helloworld.swagger.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as source:
    spec = json.load(source)
assert '/test.Greeter/SayHello' in spec['paths'], spec['paths']
PY
# 仅所有检查都通过才打印成功信息，非零退出码由 Make/Docker 继续向上传播。
echo "All language generators, TypeScript declarations, OpenAPI and documentation passed."
