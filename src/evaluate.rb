#frozen_string_literal: true

require 'set'
require 'fiber'
require_relative './context/context'
require_relative './ast/var'

# represents a negative result of the Prove/Unify operation
class UnificationFailure
end

# class implementing all the logic for evaluation
class Evaluator
  attr_accessor :occurs

  def initialize(occurs = true)
    @occurs = occurs
  end

  # used to delegate current's fiber process to other fiber
  # re-yields every successful result (Context)
  # on fail (UnificationFailure) stops resuming the fiber and returns to the caller
  def delegate(fiber)
    while true
      result = fiber.resume

      case result
      when Context
        # puts "v delegate jsem nasel nejakej context #{result}"
        Fiber.yield result
      when UnificationFailure
        break
      end
    end
  end

  # used to report on stuff like unification inside unification
  # cases where we want to report success but once it fails we also want to report the failure
  # so that this branch/fiber is never resumed again
  def transparent(fiber)
    delegate(fiber)
    unifail
  end

  # helper function to report unification failure
  def unifail
    Fiber.yield UnificationFailure.new
  end

  # helper function to yield a single correct result and then yield failure
  # doing this it signalizes there's no more valid results and should never be resumed again
  def single(ctx)
    Fiber.yield ctx
    unifail
  end

  # helper function to invert the event
  # if the resumed fiber immidiately fails --> it succeeds
  # if the resumed fiber succeeds -> it fails
  def invert(fiber, ctx)
    case fiber.resume
    when UnificationFailure
      Fiber.yield ctx
    else
      unifail
    end
  end

  # helper function to resume the fiber and return the result
  # it's just so I don't need to do unify(...).resume
  def unwrap(fiber)
    fiber.resume
  end

  # returns a Fiber which on `resume` yields either Context or UnificationFailure object
  # once it yields UnificationFailure it should never be resumed again
  # it's fine to resume it after it yielded Context
  #
  # UnificationFailure indicates this branch is absolutely unprovable
  # no other solutions could possibly be found
  def prove(term, base, context)
    Fiber.new do
      case term
      when Var
        # if the Var is associated with any value in the context -> try to prove the Val
        # if not -> fail because of insufficient instantiation
        maybe_val = context[term]
        case maybe_val
        when nil
          # instead of failing, I am gonna say that fresh variable is provable
          # but only in single model
          single(context)
          # Reason: insufficient instantiation
          # unifail
        else
          val = maybe_val
          delegate(prove(val, base, context))
        end

      when Conjunction
        left_fiber = prove(term.left, base, context) # maybe dup the context?
        while true
          result_left = left_fiber.resume
          case result_left
          when UnificationFailure
            unifail
          when Context
            ctx = result_left
            right_fiber = prove(term.right, base, ctx)
            while true
              result_right = right_fiber.resume
              case result_right
              when UnificationFailure
                break
              when Context
                Fiber.yield result_right
              end
            end
          end
        end

      when Disjunction
        delegate(prove(term.left, base, context))
        transparent(prove(term.right, base, context))

      when Negation
        invert(prove(term.arg, base, context), context)

      else
        # iterate base and try to unify term with each member of the base
        base.each do |pred|
          delegate(unify(term, pred.reify, base, context.dup))
        end
      end

      unifail
    end
  end

  # returns a Fiber which on `resume` yields either Context or UnificationFailure object
  # once it yields UnificationFailure it should never be resumed again
  # it's fine to resume it after it yielded Context
  #
  # UnificationFailure indicates this branch is absolutely unprovable
  # no other solutions could possibly be found
  def unify(left, right, base, context)
    Fiber.new do
      # trivial
      if left == right
        single(context)

      # unify wildcard with anything
      elsif left.is_a?(Wildcard) || right.is_a?(Wildcard)
        single(context)

      # unify two fresh variables
      elsif context.fresh?(left) && context.fresh?(right)
        single(context.fuse(left, right))

      # unify fresh var and one in Assoc
      # one side
      elsif context.fresh?(left) && context.assocd?(right)
        unifail if @occurs && context[right].occurs([left].to_set, context)

        single(context.assoc_to_fusassociate(right, left))
      # oposite side
      elsif context.fresh?(right) && context.assocd?(left)
        unifail if @occurs && context[left].occurs([right].to_set, context)

        single(context.assoc_to_fusassociate(left, right))

      # unify fresh var and one fused
      # one side
      elsif context.fresh?(left) && context.fused?(right)
        single(context.fuse(left, right))
      # opposite side
      elsif context.fresh?(right) && context.fused?(left)
        single(context.fuse(left, right))

      # unify fresh var and fusasscd one
      # one side
      elsif context.fresh?(left) && context.fusassocd?(right)
        unifail if @occurs && context[right].occurs([left].to_set, context)

        single(context.add_to_fusassoc(right, left))
      # opposite side
      elsif context.fresh?(right) && context.fusassocd?(left)
        unifail if @occurs && context[left].occurs([right].to_set, context)

        single(context.add_to_fusassoc(left, right))

      # unify a fresh var and non var value
      # one side
      elsif context.fresh?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs([left].to_set, context)

        single(context.associate(left, right))
      # opposite side
      elsif context.fresh?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs([right].to_set, context)

        single(context.associate(right, left))

      # unify a variable associated and a variable fused
      # one side
      elsif context.assocd?(left) && context.fused?(right)
        unifail if @occurs && context[left].occurs(context.get(right).set, context)

        single(context.assoc_plus_fused(left, right))
      # opposite side
      elsif context.assocd?(right) && context.fused?(left)
        unifail if @occurs && context[right].occurs(context.get(left).set, context)

        single(context.assoc_plus_fused(right, left))

      # unify two fused variables
      elsif context.fused?(left) && context.fused?(right)
        single(context.merge_fused(left, right))

      # unify fused variable with a non var value
      # one side
      elsif context.fused?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs(context.get(left).set, context)

        single(context.fusassociate(left, right))
      # other side
      elsif context.fused?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs(context.get(right).set, context)

        single(context.fusassociate(right, left))

      # unify a variable associated with a value and another value
      # one side
      elsif context.assocd?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs([context.get(left).var].to_set, context)

        left_val = context[left]
        transparent(unify(left_val, right, base, context))
      # other side
      elsif context.assocd?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs([context.get(right).var].to_set, context)

        right_val = context[right]
        transparent(unify(left, right_val, base, context))

      # unify a variable associated with a value and another one associated with value
      # unify a variable associated with a value and another one fusassciated with a value
      # unify two fusassociated variables
      elsif (context.assocd?(left) && context.assocd?(right)) ||
            (context.assocd?(left) && context.fusassocd?(right)) ||
            (context.fusassocd?(left) && context.assocd?(right)) ||
            (context.fusassocd?(left) && context.fusassocd?(right))

        # unify a variable associated with a value and another one associated with value
        unifail if @occurs &&
                   (context.assocd?(left) && context.assocd?(right)) &&
                   (context[left].occurs([context.get(right).var].to_set, context) ||
                   context[right].occurs([context.get(left).var].to_set, context))

        # unify a variable associated with a value and another one fusassciated with a value
        unifail if @occurs &&
                   (context.assocd?(left) && context.fusassocd?(right)) &&
                   (context[left].occurs(context.get(right).set, context) ||
                   context[right].occurs([context.get(left).var].to_set, context))

        # other side
        unifail if @occurs &&
                   (context.assocd?(right) && context.fusassocd?(left)) &&
                   (context[right].occurs(context.get(left).set, context) ||
                   context[left].occurs([context.get(right).var].to_set, context))

        # unify two fusassociated variables
        unifail if @occurs &&
                   (context.fusassocd?(left) && context.fusassocd?(right)) &&
                   (context[left].occurs(context.get(right).set, context) ||
                   context[right].occurs(context.get(left).set, context))

        left_val = context[left]
        right_val = context[right]
        transparent(unify(left_val, right_val, base, context))

      # unify a fused variable with a fusassoced variable
      # one side
      elsif context.fused?(left) && context.fusassocd?(right)
        unifail if @occurs && context[right].occurs(context.get(left).set, context)

        single(context.fused_plus_fusassocd(left, right))
      # other side
      elsif context.fused?(right) && context.fusassocd?(left)
        unifail if @occurs && context[left].occurs(context.get(right).set, context)

        single(context.fused_plus_fusassocd(right, left))

      # unify a variable fusassociated with a value and another value
      # one side
      elsif context.fusassocd?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs(context.get(left).set, context)

        left_val = context[left]
        transparent(unify(left_val, right, base, context))
      # other side
      elsif context.fusassocd?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs(context.get(right).set, context)

        right_val = context[right]
        transparent(unify(left, right_val, base, context))

      # unify a functor with a Rule
      elsif left.is_a?(Functor) && right.is_a?(Rule)
        # first match the name
        if left.name != right.name
          unifail
        end

        # match the number of arguments
        if left.arguments.length != right.arguments.length
          unifail
        end

        # unify every argument with each other
        to_unify = left.arguments.zip(right.arguments)

        to_unify.each do |l, r|
          result = unwrap(unify(l, r, base, context))
          case result
          when Context
            context = result
          when UnificationFailure
            unifail
          end
        end

        # then prove the body
        transparent(prove(right.body, base, context))

      # to unify a Predicate with a Predicate
      # two constructors for example
      elsif left.is_a?(Functor) && right.is_a?(Functor)
        # both must have the same name
        # both must have the same arity
        # all corresponding positions must unify
        if left.name != right.name
          unifail
        end

        if left.arguments.length != right.arguments.length
          unifail
        end

        # unify every argument with each other
        to_unify = left.arguments.zip(right.arguments)

        to_unify.each do |l, r|
          result = unwrap(unify(l, r, base, context))
          case result
          when Context
            context = result
          when UnificationFailure
            unifail
          end
        end
        single(context)
      end

      unifail
    end
  end
end
