#!/bin/sh
# Docker go-build 阶段入口：将 Go 实现的各语言生成器编译到 GOBIN。
# 依赖 Dockerfile 提供 Go、GOBIN/GOPROXY/CGO_ENABLED/GOFLAGS 及模块/编译缓存。
# -e：任一步失败立即退出；-u：引用未设置的变量立即失败，避免静默使用错误配置。
set -eu
# 所有模块版本或提交来自同一锁文件，不在构建时追随 @latest。
. /opt/docker-protoc/toolchain.env
# -s -w 去掉符号表和调试信息，减少交付二进制体积，不改变生成协议。
# Go 消息类型生成器，提供 protoc 的 --go_out。
go install -ldflags='-s -w' "google.golang.org/protobuf/cmd/protoc-gen-go@$GO_PROTOBUF_VERSION"
# Go gRPC 客户端/服务端生成器，提供 --go-grpc_out，与消息生成器独立发布。
go install -ldflags='-s -w' "google.golang.org/grpc/cmd/protoc-gen-go-grpc@$GO_GRPC_VERSION"
# HTTP/JSON 到 gRPC 的 Go gateway，以及配套的 OpenAPI v2 文档生成器。
# 两者使用同一个 grpc-gateway 模块版本，避免配置格式不一致。
go install -ldflags='-s -w' "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@$GRPC_GATEWAY_VERSION"
go install -ldflags='-s -w' "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@$GRPC_GATEWAY_VERSION"
# Markdown/HTML 协议文档生成器，提供 --doc_out 和 --doc_opt。
go install -ldflags='-s -w' "github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@$PROTOC_GEN_DOC_VERSION"
# PHP 服务端接口插件 2.x 使用 /v2 模块路径，按锁定的稳定版本安装。
go install -ldflags='-s -w' "github.com/hetao29/php-grpc-server-protobuf-plugin/v2@$PHP_GRPC_SERVER_VERSION"
# go install 使用模块名作为文件名；重命名为消费工程原有的 protoc 插件名称。
mv "$GOBIN/php-grpc-server-protobuf-plugin" "$GOBIN/protoc-gen-php-grpc"
