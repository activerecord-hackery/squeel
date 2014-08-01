require 'spec_helper'

module Squeel
  module Nodes
    describe Operators do

      [:+, :-, :*, :/].each do |operator|
        describe "#{operator}" do
          it "creates Operations with #{operator} operator from stubs" do
            left = Stub.new(:stubby_mcstubbenstein)
            node = left.send(operator, 1)
            expect(node).to be_an Operation
            expect(node.left).to eq left
            expect(node.operator).to eq operator
            expect(node.right).to eq 1
          end

          it "creates Operations with #{operator} operator from key paths" do
            left = KeyPath.new([:first, :second])
            node = left.send(operator, 1)
            expect(node).to be_an Operation
            expect(node.left).to eq left
            expect(node.operator).to eq operator
            expect(node.right).to eq 1
          end

          it "creates Operations with #{operator} operator from functions" do
            left = Function.new(:name, ["arg1", "arg2"])
            node = left.send(operator, 1)
            expect(node).to be_an Operation
            expect(node.left).to eq left
            expect(node.operator).to eq operator
            expect(node.right).to eq 1
          end

          it "creates Operations with #{operator} operator from operations" do
            left = Stub.new(:stubby_mcstubbenstein) + 1
            node = left.send(operator, 1)
            expect(node).to be_an Operation
            expect(node.left).to eq left
            expect(node.operator).to eq operator
            expect(node.right).to eq 1
          end
        end
      end

      describe '#op' do
        it "creates Operations with custom operator from stubs" do
          left = Stub.new(:stubby_mcstubbenstein)
          node = left.op('||', 1)
          expect(node).to be_an Operation
          expect(node.left).to eq left
          expect(node.operator).to eq '||'
          expect(node.right).to eq 1
        end

        it "creates Operations with custom operator from key paths" do
          left = KeyPath.new([:first, :second])
          node = left.op('||', 1)
          expect(node).to be_an Operation
          expect(node.left).to eq left
          expect(node.operator).to eq '||'
          expect(node.right).to eq 1
        end

        it "creates Operations with custom operator from functions" do
          left = Function.new(:name, ["arg1", "arg2"])
          node = left.op('||', 1)
          expect(node).to be_an Operation
          expect(node.left).to eq left
          expect(node.operator).to eq '||'
          expect(node.right).to eq 1
        end

        it "creates Operations with custom operator from operations" do
          left = Stub.new(:stubby_mcstubbenstein) + 1
          node = left.op('||', 1)
          expect(node).to be_an Operation
          expect(node.left).to eq left
          expect(node.operator).to eq '||'
          expect(node.right).to eq 1
        end
      end

    end
  end
end
