FROM ubuntu:24.04
LABEL maintainer="Hetao<hetao@hetao.name>"
ENV DEBIAN_FRONTEND noninteractive
ENV GOPROXY=https://goproxy.cn,direct
RUN apt-get update 
RUN apt-get install -y gnupg2 tree tar curl wget git protobuf-compiler protobuf-compiler-grpc npm golang default-jre protobuf-compiler-grpc

#https://github.com/grpc-ecosystem/grpc-gateway
#proto doc php server grpc
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@latest
RUN go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest
RUN go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@latest
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

#dart protoc
#https://grpc.io/docs/languages/dart/quickstart/
COPY linux_signing_key.pub /tmp/
RUN sh -c 'cat /tmp/linux_signing_key.pub | apt-key add -'
RUN sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
RUN apt-get update && apt-get install -y dart
RUN dart pub global activate protoc_plugin

#proto java
#https://github.com/grpc/grpc-java/tree/master/compiler
RUN curl https://maven.aliyun.com/maven2/io/grpc/protoc-gen-grpc-java/1.60.0/protoc-gen-grpc-java-1.60.0-linux-x86_64.exe > /usr/bin/protoc-gen-grpc-java
RUN chmod 755 /usr/bin/protoc-gen-grpc-java

#proto web
#https://github.com/grpc/grpc-web
RUN curl -L https://github.com/grpc/grpc-web/releases/download/1.5.0/protoc-gen-grpc-web-1.5.0-linux-x86_64 > /usr/bin/protoc-gen-grpc-web
RUN chmod 755 /usr/bin/protoc-gen-grpc-web

#proto kotlin
#https://github.com/grpc/grpc-kotlin/tree/master/compiler
RUN wget https://maven.aliyun.com/maven2/io/grpc/protoc-gen-grpc-kotlin/1.4.0/protoc-gen-grpc-kotlin-1.4.0-jdk8.jar
RUN mv protoc-gen-grpc-kotlin-1.4.0-jdk8.jar /usr/bin/
COPY bin/protoc-gen-grpc-kotlin.sh /usr/bin/
RUN chmod 755 /usr/bin/protoc-gen-grpc-kotlin.sh
RUN npm install --registry https://registry.npmmirror.com -g protoc-gen-js

#proto js
#https://github.com/protocolbuffers/protobuf-javascript/releases
RUN wget https://github.com/protocolbuffers/protobuf-javascript/releases/download/v3.21.2/protobuf-javascript-3.21.2-linux-x86_64.tar.gz
RUN tar xzf protobuf-javascript-3.21.2-linux-x86_64.tar.gz && mv bin/protoc-gen-js /usr/bin/

#proto php server
#https://github.com/roadrunner-server/roadrunner/releases
#RUN wget https://github.com/roadrunner-server/roadrunner/releases/download/v2023.3.7/protoc-gen-php-grpc-2023.3.7-linux-amd64.tar.gz
#RUN tar xzf protoc-gen-php-grpc-2023.3.7-linux-amd64.tar.gz
#RUN mv protoc-gen-php-grpc-2023.3.7-linux-amd64/protoc-gen-php-grpc /usr/bin
COPY bin/protoc-gen-php-grpc /usr/bin/

#link
RUN ln -s -f /root/go/bin/protoc-gen-doc /usr/bin/protoc-gen-doc
RUN ln -s -f /root/go/bin/protoc-gen-go /usr/bin/protoc-gen-go
RUN ln -s -f /root/go/bin/protoc-gen-go-grpc /usr/bin/protoc-gen-go-grpc
RUN ln -s -f /root/go/bin/protoc-gen-grpc-gateway /usr/bin/protoc-gen-grpc-gateway
RUN ln -s -f /root/go/bin/protoc-gen-openapiv2 /usr/bin/protoc-gen-openapiv2
RUN ln -s -f /root/.pub-cache/bin/protoc-gen-dart /usr/bin/protoc-gen-dart
