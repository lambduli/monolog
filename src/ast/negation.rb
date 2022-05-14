# frozen_string_literal: true

require 'set'

require_relative './ast'

# \+
class Negation < AST
  attr_accessor :arg

  def initialize(arg)
    @arg = arg
  end

  def to_s
    "\+ #{@arg}"
  end

  def vars
    @arg.vars
  end

  def rename(mapping)
    renamed = @arg.rename(mapping)
    Negation.new(renamed)
  end

  def dup
    Negation.new(@arg.dup)
  end

  def ==(other)
    other.instance_of?(Negation) && @arg == other.arg
  end
end
