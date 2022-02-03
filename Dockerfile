FROM ubuntu:22.04
LABEL maintainer="Hetao<hetao@hetao.name>"
ENV DEBIAN_FRONTEND noninteractive
ENV GOPROXY=https://goproxy.cn,direct
RUN apt-get update 
RUN apt-get install -y gnupg2 tree curl git golang protobuf-compiler \
	protobuf-compiler-grpc \
	protobuf-compiler-grpc-java-plugin \
	protobuf-compiler-grpc golang-grpc-gateway golang-google-genproto-dev golang-google-grpc-dev

#dart protoc
#https://grpc.io/docs/languages/dart/quickstart/
COPY linux_signing_key.pub /tmp/
RUN sh -c 'cat /tmp/linux_signing_key.pub | apt-key add -'
RUN sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
RUN apt-get update && apt-get install -y dart
RUN dart pub global activate protoc_plugin

#protoc doc
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@v1.5.0

#proto php server grpc
RUN go install github.com/hetao29/php-grpc-server-protobuf-plugin@latest

#proto java
#https://github.com/grpc/grpc-java/tree/master/compiler
RUN curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.43.2/protoc-gen-grpc-java-1.43.2-linux-x86_64.exe > /usr/bin/protoc-gen-grpc-java
RUN chmod 755 /usr/bin/protoc-gen-grpc-java

#link
RUN ln -s -f /root/go/bin/protoc-gen-doc /usr/bin/protoc-gen-doc
RUN ln -s -f /root/go/bin/php-grpc-server-protobuf-plugin /usr/bin/php-grpc-server-protobuf-plugin
RUN ln -s -f /root/.pub-cache/bin/protoc-gen-dart /usr/bin/protoc-gen-dart
