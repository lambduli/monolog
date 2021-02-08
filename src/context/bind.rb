# frozen_string_literal: true

require 'set'

# represents an abstract predecessor for Assoc and Fused and Fusassoc
class Bind
end

# represents a pair
# variable and value associated to it
class Assoc < Bind
  attr_accessor :var, :val

  # the val argument is one of [atom, literal, functor?]
  def initialize(var, val)
    @var = var
    @val = val
  end

  def to_s
    "#{var} == #{val}"
  end

  def dupl
    Assoc.new(@var.dup, @val.dup)
  end

  def ==(other)
    other.instance_of?(Assoc) && @var == other.var && @val == other.val
  end
end

# represents the group of variables fused together
class Fused < Bind
  attr_accessor :set

  # the vars are all the variables which are fused together - an collection which implements to_set
  def initialize(vars)
    @set = vars.to_set
  end

  def to_s
    inside = @set.reduce('') { |str, var| "#{str} #{var}, " }.delete_suffix(', ')
    "(|#{inside} |)"
  end

  def dup
    f = Fused.new([])
    f.set = @set.dup
    f
  end

  def ==(other)
    other.instance_of?(Fused) && @set == other.set
  end
end

# represents a group of variables fused together with the same associated value
class Fusassoc < Bind
  attr_accessor :set, :val

  def initialize(vars, val)
    @set = vars.to_set
    @val = val
  end

  def to_s
    inside = @set.reduce('') { |str, var| "#{str} #{var}, " }.delete_suffix(', ')
    "[|#{inside} == #{@val} |]"
  end

  def dup
    Fusassoc.new(@set.dup, @val.dup)
  end

  def ==(other)
    other.instance_of?(Fusassoc) && @val == other.val && @set == other.set
  end
end
