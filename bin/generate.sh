#!/bin/sh
# 镜像内统一生成入口：generate.sh 语言 协议根目录 输出根目录。
# protoc、标准 includes 与对应插件必须已经由 Dockerfile 安装。
# 语言输出为 OUTPUT_ROOT/<语言>；doc 输出为 OUTPUT_ROOT/docs/{md,html}。
set -eu
# 使用 :? 检查三个必填参数，参数缺失时直接给出错误并终止。
language=${1:?Usage: generate.sh LANGUAGE PROTO_DIR OUTPUT_ROOT}
proto_dir=${2:?Set the proto source directory}
output_root=${3:?Set the output root}

# 将同一组生成参数应用于协议目录内的 .proto；-exec ... {} + 安全传递含空格的路径并批量执行。
# 第一个 -I 是业务协议根目录，第二个 -I 是与 protoc 同版本的标准协议目录。
run() {
    find "$proto_dir" -type f -name '*.proto' -exec \
        protoc -I "$proto_dir" -I /usr/local/include "$@" {} +
}

# all 仅生成语言代码；文档单独调用 doc。Makefile 的 all 会同时执行二者。
if [ "$language" = all ]; then
    for target in go php dart cpp js web typescript python ruby java kotlin; do
        /bin/sh "$0" "$target" "$proto_dir" "$output_root"
    done
    exit 0
fi
# 生成器通常要求输出目录预先存在，因此在运行 protoc 前创建语言目录。
mkdir -p "$output_root/$language"
destination="$output_root/$language"
case "$language" in
    go)
        # 同时生成消息类型与 gRPC，避免只有 stub 却缺少消息定义。
        # 示例 RPC 没有 google.api.http 注解，通过 generate_unbound_methods 生成 HTTP 映射和 OpenAPI。
        run --go_out="$destination" --go-grpc_out="$destination" \
            --grpc-gateway_out="generate_unbound_methods=true:$destination" \
            --openapiv2_out="generate_unbound_methods=true:$destination"
        ;;
    php)
        # 第一遍：protoc 内置 PHP 消息类 + 官方 grpc_php_plugin 客户端。
        run --php_out="$destination" --grpc_out="$destination" \
            --plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin
        # 第二遍：项目使用的服务端接口插件；不重复生成消息类。
        run --grpc_out="$destination" --plugin=protoc-gen-grpc=/usr/bin/protoc-gen-php-grpc
        ;;
    # Dart 插件的 grpc 选项同时输出消息类型、客户端和服务端代码。
    dart) run --dart_out="grpc:$destination" ;;
    cpp)
        # C++ 消息由 protoc 内置生成器提供，服务代码由独立 grpc_cpp_plugin 提供。
        run --cpp_out="$destination" --grpc_out="$destination" \
            --plugin=protoc-gen-grpc=/usr/bin/grpc_cpp_plugin
        ;;
    # JS 输出 CommonJS 消息实现并启用二进制序列化，供 Node 或浏览器打包工具使用。
    js) run --js_out="import_style=commonjs,binary:$destination" ;;
    web)
        # JS 消息 + CommonJS gRPC-Web 客户端；grpcwebtext 使用文本封装的传输模式。
        run --js_out="import_style=commonjs,binary:$destination" \
            --grpc-web_out="import_style=commonjs,mode=grpcwebtext:$destination"
        ;;
    typescript)
        # 消息实现仍由 JS 生成器输出；TS 客户端与消息 .d.ts 由 gRPC-Web 插件输出。
        # import_style=typescript 只传给 --grpc-web_out，不传给 --js_out。
        run --js_out="import_style=commonjs,binary:$destination" \
            --grpc-web_out="import_style=typescript,mode=grpcwebtext:$destination"
        ;;
    python)
        # 同时生成 Python 消息、.pyi 类型声明和独立 gRPC 服务代码。
        run --python_out="$destination" --pyi_out="$destination" --grpc_out="$destination" \
            --plugin=protoc-gen-grpc=/usr/bin/grpc_python_plugin
        ;;
    ruby)
        # Ruby 消息和服务生成器拥有不同入口，但共享同一协议输入与输出目录。
        run --ruby_out="$destination" --grpc_out="$destination" \
            --plugin=protoc-gen-grpc=/usr/bin/grpc_ruby_plugin
        ;;
    # Java 消息生成器内置于 protoc，Java gRPC 插件通过 PATH 自动发现。
    java) run --java_out="$destination" --grpc-java_out="$destination" ;;
    kotlin)
        # Kotlin gRPC 代码依赖 Java 消息及 Java gRPC 描述符，因此四组输出都需要生成。
        # --kotlin_out 补充消息 DSL；--grpckt_out 通过 Java JAR 包装脚本生成协程服务代码。
        run --java_out="$destination" --kotlin_out="$destination" \
            --grpc-java_out="$destination" --grpckt_out="$destination" \
            --plugin=protoc-gen-grpckt=/usr/bin/protoc-gen-grpc-kotlin.sh
        ;;
    doc)
        # 将输入协议合并为固定名称的文档，避免将含目录的 .proto 路径误当成输出文件名。
        mkdir -p "$output_root/docs/md" "$output_root/docs/html"
        run --doc_out="$output_root/docs/md" --doc_opt=markdown,index.md
        run --doc_out="$output_root/docs/html" --doc_opt=html,index.html
        ;;
    # 未知目标使用非零退出码，保证 Make 或 Docker 构建不会将错误当作成功。
    *) echo "Unknown language: $language" >&2; exit 2 ;;
esac
