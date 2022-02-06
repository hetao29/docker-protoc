// GENERATED CODE -- DO NOT EDIT!

'use strict';
var grpc = require('grpc');
var helloworld_pb = require('./helloworld_pb.js');

function serialize_test_HelloReply(arg) {
  if (!(arg instanceof helloworld_pb.HelloReply)) {
    throw new Error('Expected argument of type test.HelloReply');
  }
  return new Buffer(arg.serializeBinary());
}

function deserialize_test_HelloReply(buffer_arg) {
  return helloworld_pb.HelloReply.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_test_HelloRequest(arg) {
  if (!(arg instanceof helloworld_pb.HelloRequest)) {
    throw new Error('Expected argument of type test.HelloRequest');
  }
  return new Buffer(arg.serializeBinary());
}

function deserialize_test_HelloRequest(buffer_arg) {
  return helloworld_pb.HelloRequest.deserializeBinary(new Uint8Array(buffer_arg));
}


// The greeting service definition.
var GreeterService = exports.GreeterService = {
  // Sends a greeting
  sayHello: {
    path: '/test.Greeter/SayHello',
    requestStream: false,
    responseStream: false,
    requestType: helloworld_pb.HelloRequest,
    responseType: helloworld_pb.HelloReply,
    requestSerialize: serialize_test_HelloRequest,
    requestDeserialize: deserialize_test_HelloRequest,
    responseSerialize: serialize_test_HelloReply,
    responseDeserialize: deserialize_test_HelloReply,
  },
};

exports.GreeterClient = grpc.makeGenericClientConstructor(GreeterService);
