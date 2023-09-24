FROM ubuntu:22.04
LABEL maintainer="Hetao<hetao@hetao.name>"
ENV DEBIAN_FRONTEND noninteractive
ENV GOPROXY=https://goproxy.cn,direct
RUN apt-get update 
RUN apt-get install -y gnupg2 tree curl git golang protobuf-compiler \
	protobuf-compiler-grpc \
	protobuf-compiler-grpc-java-plugin \
	protobuf-compiler-grpc golang-grpc-gateway golang-google-genproto-dev golang-google-grpc-dev

#protoc go
#https://protobuf.dev/reference/go/go-generated/
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

#dart protoc
#https://grpc.io/docs/languages/dart/quickstart/
COPY linux_signing_key.pub /tmp/
RUN sh -c 'cat /tmp/linux_signing_key.pub | apt-key add -'
RUN sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
RUN apt-get update && apt-get install -y dart
RUN dart pub global activate protoc_plugin


#protoc doc
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@v1.5.1

#proto php server grpc
RUN go install github.com/hetao29/php-grpc-server-protobuf-plugin@latest

#proto java
#https://github.com/grpc/grpc-java/tree/master/compiler
RUN curl https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.57.2/protoc-gen-grpc-java-1.57.2-linux-x86_64.exe > /usr/bin/protoc-gen-grpc-java
RUN chmod 755 /usr/bin/protoc-gen-grpc-java

#proto web
#https://github.com/grpc/grpc-web
RUN curl -L https://github.com/grpc/grpc-web/releases/download/1.4.2/protoc-gen-grpc-web-1.4.2-linux-x86_64 > /usr/bin/protoc-gen-grpc-web
RUN chmod 755 /usr/bin/protoc-gen-grpc-web

#proto kotlin
#https://github.com/grpc/grpc-kotlin/tree/master/compiler
RUN apt-get update && apt-get install -y default-jre
RUN curl  https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/1.3.1/protoc-gen-grpc-kotlin-1.3.1-jdk8.jar > /usr/bin/protoc-gen-grpc-kotlin-1.3.1-jdk8.jar
COPY bin/* /usr/bin/
RUN chmod 755 /usr/bin/protoc-gen-grpc-kotlin.sh

#link
RUN ln -s -f /root/go/bin/protoc-gen-doc /usr/bin/protoc-gen-doc
RUN ln -s -f /root/go/bin/php-grpc-server-protobuf-plugin /usr/bin/php-grpc-server-protobuf-plugin
RUN ln -s -f /root/.pub-cache/bin/protoc-gen-dart /usr/bin/protoc-gen-dart
