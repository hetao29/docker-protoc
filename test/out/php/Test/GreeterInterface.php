<?php
# Generated by the protocol buffer compiler (roadrunner-server/grpc). DO NOT EDIT!
# source: helloworld.proto

namespace Test;

use Spiral\RoadRunner\GRPC;

interface GreeterInterface extends GRPC\ServiceInterface
{
    // GRPC specific service name.
    public const NAME = "test.Greeter";

    /**
    * @param GRPC\ContextInterface $ctx
    * @param HelloRequest $in
    * @return HelloReply
    *
    * @throws GRPC\Exception\InvokeException
    */
    public function SayHello(GRPC\ContextInterface $ctx, HelloRequest $in): HelloReply;
}
