# frozen_string_literal: true

require 'set'

require_relative '../context'
require_relative './ast'

# _, _
class Conjunction < AST
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def to_s
    "#{@left}, #{@right}"
  end

  def vars
    @left.vars + @right.vars
  end

  def rename(mapping)
    renamed_left = @left.rename(mapping)
    renamed_right = @right.rename(mapping)
    Conjunction.new(renamed_left, renamed_right)
  end

  def dup
    Conjunction.new(@left.dup, @right.dup)
  end

  def ==(other)
    other.instance_of?(Conjunction) && @left == other.left && @right == other.right
  end
end

# _; _
class Disjunction < AST
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def to_s
    "#{@left} ; #{@right}"
  end

  def vars
    @left.vars + @right.vars
  end

  def rename(mapping)
    renamed_left = @left.rename(mapping)
    renamed_right = @right.rename(mapping)
    Disjunction.new(renamed_left, renamed_right)
  end

  def dup
    Disjunction.new(@left.dup, @right.dup)
  end

  def ==(other)
    other.instance_of?(Disjunction) && @left == other.left && @right == other.right
  end
end
