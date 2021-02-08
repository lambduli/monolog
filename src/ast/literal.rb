# frozen_string_literal: true

require 'set'

require_relative '../context'
require_relative './ast'

# Literals like strings and numbers
class Literal < AST
  attr_accessor :value # later make it protected

  def initialize(value)
    @value = value
  end

  def ==(other)
    eq?(other)
  end
end

# numeric literal
class NumLit < Literal
  def to_s
    @value.to_s
  end

  def eq?(other)
    other.instance_of?(NumLit) && @value == other.value
  end

  def dup
    NumLit.new(@value)
  end
end

# text literal
class TextLit < Literal
  def to_s
    "\"#{@value}\""
  end

  def eq?(other)
    other.instance_of?(TextLit) && @value == other.value
  end

  def dup
    TextLit.new(@value)
  end
end
