# 生成protobuf工具，支持多种语言

## 支持的语言

dart,go,php,web,js,java,kotlin,ruby,python等

## 使用方法，参考 Makefile

```bash
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
all:
    #https://github.com/hetao29/docker-protoc
    #生成client
    find proto/src/ -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
        --plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin --grpc_out=proto_generated --php_out=proto_generated -I proto/ -I . \
        "{}"
    #生成服务端interface
    find proto/src/ -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
        --plugin=protoc-gen-grpc=/usr/bin/protoc-gen-php-grpc --grpc_out=proto_generated --php_out=proto_generated -I proto/ -I . \
        "{}"
```

