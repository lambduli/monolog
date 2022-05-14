#frozen_string_literal: true

require 'set'
require 'fiber'
require_relative './context'

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

    # puts 'Tohle by se nemelo nikdy stat. Nekdo resumnul Fiber po tom co Fialnulo.'
  end

  # helper function to yield a single correct result and then yield failure
  # doing this it signalizes there's no more valid results and should never be resumed again
  def single(ctx)
    Fiber.yield ctx
    unifail
  end

  # returns a Fiber which on `resume` yields either Context or UnificationFailure object
  # once it yields UnificationFailure it should never be resumed again
  # it's fine to resume it after it yielded Context
  #
  # UnificationFailure indicates this branch is absolutely unprovable
  # no other solutions could possibly be found
  def prove(term, base, context)
    # musim vytvorit novy Fiber
    # uvnitr nej budu prochazet base.each
    # volani unify poslu do `delegate`, kterou si napisu
    # `delegate` obsahuje while true a resumuje fiber co dostal tak dlouho dokud nedostane Fail
    # `delegate` ale Fail nepropaguje, protoze kdyby to udelal, tak by se ten Fail odsud dostal ven
    # dostal by ho top level napriklad a myslel by, ze ma skoncit -> to nechceme
    # misto toho, kdyz delegate narazi na Fail -> tise breakne smycku a vrati se sem
    # coz umozni prejiti k dalsimu prvku `base` a unifikovani s nim

    # rusime uplne listy, pokazdy jenom jeden context

    # vsechno tohle bude uvnitr Fiber.new do
    # list = []

    Fiber.new do
      case term
      when Conjunction
        # v pripade ze dokazuju konjunkci -> chci nejdriv dokazat left
        # to znamena, ze resumnu left a budto dostanu context nebo fail
        # pokud fail -> yieldnu fail a tady jsme skoncili
        # pokud context -> vezmu ho a zkusim v nem provnout right
        # to znamena zase resume a budto dostanu fail -> opet konec
        # nebo dostanu context -> ten yieldnu
        # pokud by ale chtel backtrackovat, tak to znamena, ze se musim vratit a vytocit znova right
        # right se bude tocit tak dlouho dokud neda Fail -> pak se vratim k leftu a vytocim ho znova
        # a vlastne provedu znova celej right s uplne novym contextem
        # takze to vede na nejakej loop nad leftem - kterej toci left tak dlouho, dokud nepadne fail, fail vrati a uz by ho nikdo nikdy nemel znova resumnout
        # uvnitr je loop nad rightem - ten toci right, vzdycky s tim, co mu left provnulo, pokud v right vyjde fail
        # tak breakne -> tim se skoci znova do dalsiho cyklu leftu NAD
        # pokud rightu vyjde Context, tak ho yieldne a nic dalsiho nedela, pokud bude znova resumnutej
        # tak proste pojede dalsi kolo rightu -> tedy se pokusi provnout right jeste jinak
        # jo moment, to znamena, ze bude na resume muset zavolat yield right_fiber.resume
        # to samy bude delat ofc left, kdyz bude chtit najit dalsi context/fail
        # OK
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

        # ctxts = prove(term.left, base, context)
        # ctxts.each do |ctx|
        #   cs = prove(term.right, base, ctx)
        #   list.concat(cs)
        # end

      when Disjunction
        # v pripade ze dokazuju disjunkci
        # nejdriv zkusim dokazat left a pak nezavisle na tom zkusim dokazat right
        # to znamena:
        # tocim left tak dlouho dokud neco pada
        # kdyz padat prestane, jdu tocit right tak dloho dokud neco pada
        # kdyz prestane padat right -> unifal
        delegate(prove(term.left, base, context))
        transparent(prove(term.right, base, context))

        # left_fiber = prove(term.left, base, context)
        # while true
        #   result_left = left_fiber.resume
        #   case result_left
        #   when UnificationFailure
        #     unifail
        #   when Context


      else
        # iterate base and try to unify term with each member of the base
        # tohle uz je vetsinou popsany uplne nahore
        #
        base.each do |pred|
          # puts "snazim se provnout: #{term} === #{pred.reify}"
          delegate(unify(term, pred.reify, base, context.dup))
          # ctxs = unify(term, pred.reify, base, context.dup)
          # list.concat(ctxs)
        end
      end

      # puts 'nepodarilo semi provnout nic tak failnu'
      unifail
      # list
    end
  end

  # returns a Fiber which on `resume` yields either Context or UnificationFailure object
  # once it yields UnificationFailure it should never be resumed again
  # it's fine to resume it after it yielded Context
  #
  # UnificationFailure indicates this branch is absolutely unprovable
  # no other solutions could possibly be found
  def unify(left, right, base, context)
    # puts "zavolal jsem unify "
    Fiber.new do
      # puts "trying to unify #{left} with #{right}  in the context: #{context}"
      # trivial
      if left == right
        single(context)
        # return [context]

      # unify wildcard with anything
      elsif left.is_a?(Wildcard) || right.is_a?(Wildcard)
        single(context)
        # return [context]

      # unify two fresh variables
      elsif context.fresh?(left) && context.fresh?(right)
        single(context.fuse(left, right))
        # return [context.fuse(left, right)]

      # unify fresh var and one in Assoc
      # one side
      elsif context.fresh?(left) && context.assocd?(right)
        unifail if @occurs && context[right].occurs([left].to_set, context)
        # return [] if context[right].occurs([left].to_set)

        single(context.assoc2fusassociate(right, left))
        # return [context.assoc2fusassociate(right, left)]
      # oposite side
      elsif context.fresh?(right) && context.assocd?(left)
        unifail if @occurs && context[left].occurs([right].to_set, context)
        # return [] if context[left].occurs([right].to_set)

        single(context.assoc2fusassociate(left, right))
        # return [context.assoc2fusassociate(left, right)]

      # unify fresh var and one fused
      # one side
      elsif context.fresh?(left) && context.fused?(right)
        single(context.fuse(left, right))
        # return [context.fuse(left, right)]
      # opposite side
      elsif context.fresh?(right) && context.fused?(left)
        single(context.fuse(left, right))
        # return [context.fuse(left, right)]

      # unify fresh var and fusasscd one
      # one side
      elsif context.fresh?(left) && context.fusassocd?(right)
        unifail if @occurs && context[right].occurs([left].to_set, context)
        # return [] if context[right].occurs([left].to_set)

        single(context.add2fusassoc(right, left))
        # return [context.add2fusassoc(right, left)]
      # opposite side
      elsif context.fresh?(right) && context.fusassocd?(left)
        unifail if @occurs && context[left].occurs([right].to_set, context)
        # return [] if context[left].occurs([right].to_set)

        single(context.add2fusassoc(left, right))
        # return [context.add2fusassoc(left, right)]

      # unify a fresh var and non var value
      # one side
      elsif context.fresh?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs([left].to_set, context)
        # return [] if right.occurs([left].to_set)

        single(context.associate(left, right))
        # return [context.associate(left, right)]
      # opposite side
      elsif context.fresh?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs([right].to_set, context)
        # return [] if left.occurs([right].to_set)

        single(context.associate(right, left))
        # return [context.associate(right, left)]

      # unify a variable associated and a variable fused
      # one side
      elsif context.assocd?(left) && context.fused?(right)
        unifail if @occurs && context[left].occurs(context.get(right).set, context)
        # return [] if context[left].occurs(context.get(right).set)

        single(context.assoc_plus_fused(left, right))
        # return [context.assoc_plus_fused(left, right)]
      # opposite side
      elsif context.assocd?(right) && context.fused?(left)
        unifail if @occurs && context[right].occurs(context.get(left).set, context)
        # return [] if context[right].occurs(context.get(left).set)

        single(context.assoc_plus_fused(right, left))
        # return [context.assoc_plus_fused(right, left)]

      # unify two fused variables
      elsif context.fused?(left) && context.fused?(right)
        single(context.merge_fused(left, right))
        # return [context.merge_fused(left, right)]

      # unify fused variable with a non var value
      # one side
      elsif context.fused?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs(context.get(left).set, context)
        # return [] if right.occurs(context.get(left).set)

        single(context.fusassociate(left, right))
        # return [context.fusassociate(left, right)]
      # other side
      elsif context.fused?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs(context.get(right).set, context)
        # return [] if left.occurs(context.get(right).set)

        single(context.fusassociate(right, left))
        # return [context.fusassociate(right, left)]

      # unify a variable associated with a value and another value
      # one side
      elsif context.assocd?(left) && !right.instance_of?(Var)
        unifail if @occurs && right.occurs([context.get(left).var].to_set, context)
        # return [] if right.occurs([context.get(left).var].to_set)

        left_val = context[left]
        transparent(unify(left_val, right, base, context))
        # return unify(left_val, right, base, context)
      # other side
      elsif context.assocd?(right) && !left.instance_of?(Var)
        unifail if @occurs && left.occurs([context.get(right).var].to_set, context)
        # return [] if left.occurs([context.get(right).var].to_set)

        right_val = context[right]
        transparent(unify(left, right_val, base, context))
        # return unify(left, right_val, base, context)

      # unify a variable associated with a value and another one associated with value
      # unify a variable associated with a value and another one fusassciated with a value
      # unify variables fusassociated and associated with some values -- ^^^ the same thing
      # unify two fusassociated variables
      elsif (context.assocd?(left) && context.assocd?(right)) ||
            (context.assocd?(left) && context.fusassocd?(right)) ||
            (context.assocd?(right) && context.fusassocd?(left)) ||
            # (context.fusassocd?(left) && context.assocd?(right)) ||
            # (context.fusassocd?(right) && context.assocd?(left)) ||
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
        # return unify(left_val, right_val, base, context)

      # unify a fused variable with a fusassoced variable
      # one side
      elsif context.fused?(left) && context.fusassocd?(right)
        unifail if @occurs && context[right].occurs(context.get(left).set, context)

        single(context.fused_plus_fusassocd(left, right))
        # return [context.fused_plus_fusassocd(left, right)]
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
          # return []
          # raise 'Cannot unify predicate and fact with different names.'
        end

        # match the number of arguments
        if left.arguments.length != right.arguments.length
          unifail
          # return []
          # raise 'Cannot unify predicate and fact with different arity.'
        end

        # unify every argument with each other
        to_unify = left.arguments.zip(right.arguments)

        # contexts = to_unify.reduce([context]) do |ctxts, to_unif|
        #   l, r = to_unif
        #   lst = []
        #   ctxts.each do |ctxt|
        #     cxs = unify(l, r, base, ctxt)
        #     lst.concat(cxs)
        #   end
        #   lst
        # end

        to_unify.each do |l, r|
          result = unify(l, r, base, context).resume
          case result
          when Context
            context = result
          when UnificationFailure
            unifail
          end
        end

        # then prove the body
        transparent(prove(right.body, base, context))

        # lst = []
        # contexts.each do |ctxt|
        #   cxs = prove(right.body, base, ctxt)
        #   lst.concat(cxs)
        # end

        # return lst

      # to unify a Predicate with a Predicate
      # two constructors for example
      elsif left.is_a?(Functor) && right.is_a?(Functor)
        # both must have the same name
        # both must have the same arity
        # all corresponding positions must unify
        if left.name != right.name
          unifail
          # return []
          # raise 'Cannot unify predicate and fact with different names.'
        end

        if left.arguments.length != right.arguments.length
          unifail
          # return []
          # raise 'Cannot unify predicate and fact with different arity.'
        end

        # unify every argument with each other
        to_unify = left.arguments.zip(right.arguments)

        # contexts = to_unify.reduce([context]) do |ctxts, to_unif|
        #   l, r = to_unif
        #   lst = []
        #   ctxts.each do |ctxt|
        #     cxs = unify(l, r, base, ctxt)
        #     lst.concat(cxs)
        #   end
        #   lst
        # end

        # return contexts
        # to_unify = left.arguments.zip(right.arguments)

        to_unify.each do |l, r|
          result = unify(l, r, base, context).resume
          case result
          when Context
            context = result
          when UnificationFailure
            unifail
          end
        end
        single(context)
        # return context
      end

      unifail
    end

    # puts '....................................................................'
    # puts '....................................................................'
    # puts "failed to unify #{left} with #{right}  in the context: #{context}"
    # puts 'neco jsem pokazil'
    # puts "left class #{left.class.name}  right class #{right.class.name}   left value #{left}   right value #{right}"
    # puts "left fresh? #{context.fresh?(left)}     right fresh? #{context.fresh?(right)}"
    # puts "left fused? #{context.fused?(left)}     right fused? #{context.fused?(right)}"
    # puts "left assoc? #{context.assocd?(left)}    right assoc? #{context.assocd?(right)}"
    # puts "left fusassocd? #{context.fusassocd?(left)}     right fusassocd? #{context.fusassocd?(right)}"
    # puts "left value #{context[left]}      right value #{context[right]}"
    # puts '---------------------------------------------------------------------'
    # puts '---------------------------------------------------------------------'
    # raise 'Cannot unify these two things.'
  end
end