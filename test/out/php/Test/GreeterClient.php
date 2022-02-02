<?php
// GENERATED CODE -- DO NOT EDIT!

namespace Test;

/**
 * The greeting service definition.
 */
class GreeterClient extends \Grpc\BaseStub {

    /**
     * @param string $hostname hostname
     * @param array $opts channel options
     * @param \Grpc\Channel $channel (optional) re-use channel object
     */
    public function __construct($hostname, $opts, $channel = null) {
        parent::__construct($hostname, $opts, $channel);
    }

    /**
     * Sends a greeting
     * @param \Test\HelloRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Test\HelloReply
     */
    public function SayHello(\Test\HelloRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/test.Greeter/SayHello',
        $argument,
        ['\Test\HelloReply', 'decode'],
        $metadata, $options);
    }

}
