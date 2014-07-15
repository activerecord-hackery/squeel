require 'polyamorous/tree_node'

module Squeel
  module Nodes
    class Node
      include ::Polyamorous::TreeNode

      def each(&block)
        return enum_for(:each) unless block_given?

        Visitors::EnumerationVisitor.new(block).accept(self)
      end

      # We don't want the full Enumerable method list, because it will mess
      # with stuff like KeyPath
      def grep(object, &block)
        if block_given?
          each { |value| yield value if object === value }
        else
          [].tap do |results|
            each { |value| results << value if object === value }
          end
        end
      end
    end
  end
end
