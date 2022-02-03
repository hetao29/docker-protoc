# docker-protoc

## protoc support language
1. golang
2. php
3. dart

## usage

```bash
make php
make go
make dart
make doc
```

## Makefile 

```makefile

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

test:
	sudo docker run hetao29/docker-protoc:latest protoc -h
build:
	sudo docker build . -t hetao29/docker-protoc:latest
push:
	sudo docker push -a hetao29/docker-protoc

go:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--grpc-gateway_out=logtostderr=true:test/out/go \
		--plugin=proto-google-common-protos --go_out=plugins=grpc:test/out/go \
		-I test/proto/ -I . \
		"{}"
php:
	#生成标准+客户端库
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin --grpc_out=test/out/php --php_out=test/out/php -I test/proto/ -I . \
		"{}"
	#生成服务端interface
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--plugin=protoc-gen-grpc=/usr/bin/php-grpc-server-protobuf-plugin --grpc_out=test/out/php --php_out=test/out/php -I test/proto/ -I . \
		"{}"

dart:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--dart_out=grpc:test/out/dart \
		"{}"
doc:
	#https://github.com/pseudomuto/protoc-gen-doc
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest  protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--doc_out=./test/docs/md \
		--doc_opt=markdown,"{}".md \
		"{}"
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--doc_out=./test/docs/html \
		--doc_opt=html,"{}".html \
		"{}"
    
```
