# frozen_string_literal: true

require 'set'

require_relative './ast'

# atoms are special terms
class Atom < AST
  attr_accessor :value # later make it protected

  def initialize(value)
    @value = value
  end

  def to_s
    @value
  end

  def dup
    Atom.new(@value)
  end

  def ==(other)
    other.instance_of?(Atom) && @value == other.value
  end
end
