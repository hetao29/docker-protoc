# 统一从本 Makefile 所在目录运行，使用 make -f /path/to/Makefile 时也能定位工程。
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
# 以下变量均可在命令行覆盖，例如 make test DOCKER=docker IMAGE=仓库:标签。
# DOCKER：Docker 命令前缀；默认兼容需要 sudo 才能访问 daemon 的宿主机。
DOCKER ?= sudo docker
# IMAGE：构建、运行和直接推送所用的完整镜像名。
IMAGE ?= hetao29/docker-protoc:latest
# VERSION：镜像发布标签；36.2.1 对应 protoc 36.2 + PHP 服务端插件 2.0.0。
VERSION ?= 36.2.1
# REPOSITORY：push-tag 的目标仓库，与 IMAGE 的源镜像名称可以不同。
REPOSITORY ?= hetao29/docker-protoc
# 临时容器退出后自动删除；工程以相同绝对路径挂载，并设置一致的容器工作目录。
# 生成文件写回宿主机，--rm 只清理容器，不清理挂载目录内的输出。
RUN = $(DOCKER) run --rm -v "$(ROOT_DIR):$(ROOT_DIR)" -w "$(ROOT_DIR)" $(IMAGE)
# 各语言复用 bin/generate.sh；新增目标时同步补充 smoke-test.sh 和文档。
LANGUAGES := go php dart cpp js web typescript python ruby java kotlin

# 声明伪目标，防止 test/ 等同名目录导致 make 误判目标已经完成。
.PHONY: test build all $(LANGUAGES) ts doc versions push push-tag
# 裸 make 执行生成验证；镜像需要事先通过 make build 构建。
.DEFAULT_GOAL := test

# 在镜像内部的临时目录运行全部生成器，不挂载工程，因此不会覆盖宿主机样例。
# 检查编译器版本、关键输出、Python 语法、OpenAPI 和文档；消费端运行测试另行执行。
test:
	$(DOCKER) run --rm $(IMAGE) /bin/sh /usr/local/bin/smoke-test.sh

# 使用默认 Dockerfile 完整构建全部工具链；plain 日志便于定位下载和编译失败。
# Dockerfile 最后会执行 smoke-test，只有检查通过才会产出成功的最终镜像。
build:
	$(DOCKER) build --progress=plain -t $(IMAGE) .

# 在宿主机更新所有语言样例和合并文档，不构建镜像，也不执行推送。
all: $(LANGUAGES) doc

# 多目标共享配方：$@ 展开为本次具体语言名，输出目录由脚本自动创建。
# go 包含消息/gRPC/gateway/OpenAPI；php 包含客户端和服务端接口。
# kotlin 同时生成 Java 消息、Kotlin DSL 和 Java/Kotlin gRPC；typescript 包含消息类型声明。
$(LANGUAGES):
	$(RUN) /bin/sh /usr/local/bin/generate.sh $@ test/proto test/out

# TypeScript 的简写入口，保持实际输出目录名为 test/out/typescript。
ts: typescript

# 第三个参数传 test，使合并文档写入 test/docs/md/index.md 和 test/docs/html/index.html。
doc:
	$(RUN) /bin/sh /usr/local/bin/generate.sh doc test/proto test

# 查看镜像内的锁定配置；其中也包含构建依赖版本，不等同于消费工程的运行库版本。
versions:
	$(DOCKER) run --rm $(IMAGE) cat /opt/docker-protoc/toolchain.env

# 仅推送 IMAGE 指定的一个标签，不再使用 docker push -a 推送所有本地标签。
push:
	$(DOCKER) push $(IMAGE)

# 给已经构建的 IMAGE 添加明确的发布标签再推送，不在这里重新构建。
# 发布前确认 REPOSITORY 和 VERSION，避免把新工具链覆盖到旧版本标签。
push-tag:
	$(DOCKER) tag $(IMAGE) $(REPOSITORY):$(VERSION)
	$(DOCKER) push $(REPOSITORY):$(VERSION)
