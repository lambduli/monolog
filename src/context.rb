# frozen_string_literal: true

require 'set'

# represents abstract predecessor for Assoc and Fused and Fusassoc
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
end

# manages all the bindings
class Context
  attr_accessor :arr

  def initialize
    @arr = []
  end

  # tests whether the `var` is associated with any value or fused with another one or more variables
  # simply put: whether `var` is already present in the Context
  def key?(var)
    @arr.any? do |bind|
      case bind
      when Assoc
        bind.var == var
      when Fused
        bind.set.include?(var)
      when Fusassoc
        bind.set.include?(var)
      end
    end
  end

  # this method does not test either of arguments for correct type
  def associate(var, val)
    @arr.push(Assoc.new(var, val))
    self
  end

  def fuse(var_l, var_r)
    # find the position in the array
    # if there's no fusion already -> create one
    # if there is -> add both to the fusion
    el = @arr.find { |bind| bind.is_a?(Fused) && (bind.set.include?(var_l) || bind.set.include?(var_r)) }
    if el.nil?
      @arr.push(Fused.new([var_l, var_r]))
    else
      el.set.add(var_l)
      el.set.add(var_r)
    end
    self
  end

  def fusassociate(var_fuse, val)
    # var_fused must be in the correct binding in the context
    # val must be an atom/literal/functor
    fused = get(var_fuse)

    fusassoc = Fusassoc.new(fused.set, val)
    remove(fused)
    @arr.push(fusassoc)
    self
  end

  def add2fusassoc(var_l, var_r)
    l_bind = get(var_l)
    case l_bind
    when Fusassoc
      l_bind.set.add(var_r)
    else
      r_bind = get(var_r)
      case r_bind
      when Fusassoc
        r_bind.set.add(var_l)
      end
    end
    self
  end

  def assoc2fusassociate(var_l, var_r)
    # finds the one in Assoc and creates Fusassoc + removes the Assoc
    l_bind = get(var_l)
    case l_bind
    when Assoc
      @arr.push(Fusassoc.new([var_l, var_r], l_bind.val))
      remove(l_bind)
    else
      r_bind = get(var_r)
      case r_bind
      when Assoc
        @arr.push(Fusassoc.new([var_l, var_r], r_bind.val))
        remove(r_bind)
      end
    end

    self
  end

  # merges an Assoc and a Fused together into a Fusassoc
  def assoc_plus_fused(var_assoc, var_fused)
    # the order must be adhered to
    # and both vars must be in the correct binding in the Context
    assoc_bind = get(var_assoc)
    fusion_bind = get(var_fused)

    fusassoc = Fusassoc.new(fusion_bind.set.add(var_assoc), assoc_bind.val)
    remove(assoc_bind)
    remove(fusion_bind)
    @arr.push(fusassoc)
    self
  end

  # adds all the vars in the Fused into the Fusassoc
  def fused_plus_fusassocd(var_fused, var_fusassocd)
    # both vars must be in the correct bindings in the Context
    fused = get(var_fused)
    fusassocd = get(var_fusassocd)

    fusassocd.set.merge(fused.set)
    remove(fused)
    self
  end

  # merges two Fused together
  def merge_fused(var_left, var_right)
    # both vars must be in the correct binding in the Context
    left_bind = get(var_left)
    right_bind = get(var_right)

    merged = left_bind.set.merge(right_bind.set)
    remove(left_bind)
    remove(right_bind)
    @arr.push(Fused.new(merged))
    self
  end

  # if the var argument is not a Variable or a fresh one -> nil
  # otherwise it looks up its binding and returns the associated value or nil (in case of Fused)
  def [](var)
    return nil if fresh?(var)

    bind = get(var)

    case bind
    when Fused
      nil
    else
      bind.val
    end
  end

  # test's whether the var argument is associated with any value
  def has_value?(var)
    !self[var].nil?
  end

  def get(var)
    # var should be variable
    # this method returns either nil or an instance of either Fused or Assoc or Fusassoc
    @arr.find do |bind|
      case bind
      when Assoc
        bind.var == var
      when Fused
        bind.set.include?(var)
      when Fusassoc
        bind.set.include?(var)
      else
        false
      end
    end
  end

  # Var is a fresh if it is an instance of a Variable and it's not present in the Context
  def fresh?(var)
    var.is_a?(Var) && !key?(var)
  end

  # tests whther the var argument is in the Assoc binding
  def assocd?(var)
    return false if !var.instance_of?(Var) || fresh?(var)

    case get(var)
    when Assoc
      true
    else
      false
    end
  end

  # tests whether the var argument is in the Fused binding
  def fused?(var)
    return false if !var.instance_of?(Var) || fresh?(var)

    case get(var)
    when Fused
      true
    else
      false
    end
  end

  # tests whether the var argument is in the Fusassoc binding
  def fusassocd?(var)
    return false if !var.instance_of?(Var) || fresh?(var)

    case get(var)
    when Fusassoc
      true
    else
      false
    end
  end

  # removes given binding (Assoc, Fused, Fusassoc) from the Context
  def remove(bind)
    @arr = @arr.filter { |b| b != bind }
    self
  end

  def to_s
    inside = @arr.reduce('') do |str, bind|
      "#{str} #{bind}, "
    end

    "{ #{inside.delete_suffix(', ')} }"
  end

  def dup
    ctx = Context.new
    ctx.arr = @arr.map { |bind| bind.dup }
    ctx
  end
end
