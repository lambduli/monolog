# frozen_string_literal: true

require 'set'

require_relative '../context/bind'
require_relative './ast'

# variables
class Var < AST
  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def to_s
    @name
  end

  def ==(other)
    other.instance_of?(Var) && @name == other.name
  end

  def vars
    [@name]
  end

  def rename(mapping)
    new_name = mapping[@name]
    Var.new(new_name)
  end

  def dup
    Var.new(@name)
  end

  def hash
    @name.hash
  end

  def eql?(other)
    return false unless other.instance_of?(Var)

    @name == other.name
  end

  def specify(context, user_vars)
    bind = context.get(self)

    case bind
    when Assoc
      # Because the Monolog language doesn't contain explicit unification operator =
      # it shouldn't be possible to fail the occurs check with just a variable associated with a value containing itself
      # so I don't expect to need to take care of that matter when presenting/specifying the content of user variables

      bind.val.specify(context, user_vars)
    when Fusassoc
      var_set = bind.set.-([self])
      if bind.val.unsafe_occurs(var_set, context)
        inter = bind.set.&(user_vars)
        if user_vars.include?(self)
          return bind.val.specify(context, user_vars)
        elsif inter.empty?
          return self
        else
          return inter.to_a[0]
        end
      end

      bind.val.specify(context, user_vars)
    when Fused
      # if there's an intersection between fused.set (minus self) and user_vars
      # I think it's safe to just return any variable from that intersection
      intersection = bind.set.-([self]).&(user_vars)
      if intersection.empty?
        Var.new("_100#{bind.set.to_a[0].name.delete_prefix('_')}")
      else
        intersection.to_a[0]
      end
    end
  end

  def occurs(var_set, context)
    return true if var_set.include?(self)

    maybe_val = context[self]
    case maybe_val
    when nil
      false
    else
      val = maybe_val
      val.occurs(var_set, context)
    end
  end

  # This method should only be used during specification of the term!
  # occurs can be used in an unsafe way
  # doing the occurs check while the context does already fails occurs check itself
  # I expect occurs check to fail only around Fusassoc
  def unsafe_occurs(var_set, context)
    return true if var_set.include?(self)

    maybe_bind = context.get(self)

    case maybe_bind
    when Fusassoc
      return true unless maybe_bind.set.&(var_set.-([self])).empty?

      val = maybe_bind.val
      val.unsafe_occurs(var_set, context)
    when nil
      false
    when Fused
      false
    else
      # Because the Monolog language doesn't contain explicit unification operator =
      # it shouldn't be possible to fail the occurs check with just a variable associated with a value containing itself
      # so I don't expect to need to take care of that matter when presenting/specifying the content of user variables
      val = maybe_bind.val
      val.unsafe_occurs(var_set, context)
    end
  end
end
