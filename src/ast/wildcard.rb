# frozen_string_literal: true

require 'set'

require_relative '../context'
require_relative './ast'

# _
class Wildcard < AST
  def to_s
    '_'
  end

  def dup
    Wildcard.new
  end

  def ==(other)
    other.instance_of?(Wildcard)
  end
end
