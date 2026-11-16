#!/usr/bin/env sh

# protoc 需要可执行插件入口，而 Kotlin 官方生成器发布为 JAR，因此由 Java 运行它。
# JAR 安装路径固定，具体版本由 toolchain.env 和安装脚本管理。
# 保持标准输入/输出的插件二进制协议，不额外向 stdout 写日志；所有参数原样传递。
# exec 使 Java 直接接收终止信号，并将其退出码直接返回给 protoc。
exec java -jar /usr/bin/protoc-gen-grpc-kotlin.jar "$@"
