import { HelloRequest, HelloReply } from './generated/helloworld_pb.js';
import { GreeterClient } from './generated/HelloworldServiceClientPb.js';

const request = new HelloRequest();
request.setName('toolchain-upgrade');
const name: string = request.getName();
const bytes: Uint8Array = request.serializeBinary();
const restored: HelloRequest = HelloRequest.deserializeBinary(bytes);
const reply = new HelloReply();
reply.setMessage(name);
const client: GreeterClient = new GreeterClient('http://localhost:8080');
void [restored, reply, client];
