import * as jspb from 'google-protobuf'



export class HelloRequest extends jspb.Message {
  constructor();
  constructor(opt_data?: HelloRequest.AsObject);
  getName(): string;
  setName(value: string): HelloRequest;
  hasName(): boolean;
  clearName(): HelloRequest;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): HelloRequest.AsObject;
  static toObject(includeInstance: boolean, msg: HelloRequest): HelloRequest.AsObject;
  static serializeBinaryToWriter(message: HelloRequest, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): HelloRequest;
  static deserializeBinaryFromReader(message: HelloRequest, reader: jspb.BinaryReader): HelloRequest;
}

export namespace HelloRequest {
  export type AsObject = {
    name?: string;
  };

  export enum NameCase {
    _NAME_NOT_SET = 0,
    NAME = 1,
  }
}

export class HelloReply extends jspb.Message {
  constructor();
  constructor(opt_data?: HelloReply.AsObject);
  getMessage(): string;
  setMessage(value: string): HelloReply;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): HelloReply.AsObject;
  static toObject(includeInstance: boolean, msg: HelloReply): HelloReply.AsObject;
  static serializeBinaryToWriter(message: HelloReply, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): HelloReply;
  static deserializeBinaryFromReader(message: HelloReply, reader: jspb.BinaryReader): HelloReply;
}

export namespace HelloReply {
  export type AsObject = {
    message: string;
  };
}

