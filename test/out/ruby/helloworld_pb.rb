# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: helloworld.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("helloworld.proto", :syntax => :proto3) do
    add_message "test.HelloRequest" do
      optional :name, :string, 1
    end
    add_message "test.HelloReply" do
      optional :message, :string, 1
    end
  end
end

module Test
  HelloRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("test.HelloRequest").msgclass
  HelloReply = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("test.HelloReply").msgclass
end