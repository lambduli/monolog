# frozen_string_literal: true

# represents abstract predecessor for Assoc and Fused
class Binding
end

# represents a pair
# variable and value associated to it
class Assoc < Binding
  attr_accessor :var, :val

  # the val argument is one of [atom, literal, functor?]
  def initialize(var, val)
    @var = var
    @val = val
  end
end

# represents the group of variables fused together
class Fused < Binding
  attr_accessor :set

  # the vars are all the variables which are fused together - an collection which implements to_set
  def initialize(vars)
    @set = vars.to_set
  end
end

# manages all the bindings
class Context
  def initialize
    @arr = []
  end

  def key?(var)
    @arr.any? do |bind|
      return bind.var == var if bind.instance_of?(Assoc)

      return bind.set.include?(var) if bind.instance_of(Fused)
    end
  end

  # this method does not test either of arguments for correct type
  def associate(var, val)
    @arr.push(Assoc.new(var, val))
  end

  def fuse(var_l, var_r)
    # find the position in the array
    # if there's no fusion already -> create one
    # if there is -> add both to the fusion
    el = @arr.find { |bind| bind.instance_of?(Fused) && (bind.set.include?(var_l) || bind.set.include?(var_r)) }
    if el.nil?
      @arr.push(Fused.new([var_l, var_r]))
    else
      el.set.add(var_l)
      el.set.add(var_r)
    end
  end

  def [](var)
    # var should be variable
    # this method returns either nil or an instance of either Fused or Assoc
    @arr.find do |bind|
      return bind.var == var if bind.instance_of?(Assoc)

      return bind.set.include?(var) if bind.instance_of(Fused)
    end
  end

  # def each
  #   @arr.each { |a, b| yield(a, b) }
  # end

  # def map(&block)
  #   @arr.map(&block)

  #   self
  # end

  # def filter(&block)
  #   @arr = @arr.filter(&block)

  #   self
  # end
end
