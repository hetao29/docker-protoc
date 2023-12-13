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
		--plugin=proto-google-common-protos --go-grpc_out=test/out/go \
		-I test/proto/ -I . \
		"{}"
php:
	#生成标准+客户端库
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin --grpc_out=test/out/php --php_out=test/out/php -I test/proto/ -I . \
		"{}"
	#生成服务端interface
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -v /tmp:/tmp -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--plugin=protoc-gen-grpc=/usr/bin/protoc-gen-php-grpc --grpc_out=test/out/php --php_out=test/out/php -I test/proto/ -I . \
		"{}"

dart:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--dart_out=grpc:test/out/dart \
		"{}"
cpp:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_cpp_plugin \
		--cpp_out=test/out/cpp \
		--grpc_out=test/out/cpp \
		"{}"
js:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpc=/usr/bin/protoc-gen-js \
		--js_out=test/out/js \
		"{}"
web:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpc=/usr/bin/protoc-gen-grpc-web \
		--js_out=import_style=commonjs:test/out/web \
		--grpc-web_out=import_style=commonjs,mode=grpcwebtext:test/out/web \
		"{}"
python:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_python_plugin \
		--python_out=test/out/python \
		--grpc_out=test/out/python \
		"{}"
ruby:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_ruby_plugin \
		--ruby_out=test/out/ruby \
		--grpc_out=test/out/ruby \
		"{}"

java:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
        --plugin=protoc-gen-grpc-java=/usr/bin/protoc-gen-grpc-java \
        --java_out=test/out/java \
        --grpc-java_out=test/out/java \
		"{}"

kotlin:
	find test/proto -name "*.proto" | xargs -I {} sudo docker run --rm -v ${ROOT_DIR}:${ROOT_DIR} -w ${ROOT_DIR} hetao29/docker-protoc:latest protoc \
		--proto_path=test/proto \
		--proto_path=. \
		--plugin=protoc-gen-grpckt=/usr/bin/protoc-gen-grpc-kotlin.sh \
		--java_out=test/out/kotlin \
		--grpckt_out=test/out/kotlin \
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
