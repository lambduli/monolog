#frozen_string_literal: true

require_relative './context'

def prove(term, base, context)
  list = []
  case term
  when Conjunction
    ctxts = prove(term.left, base, context)
    ctxts.each do |ctx|
      cs = prove(term.right, base, ctx)
      list.concat(cs)
    end
  else
    # iterate base and try to unify term with each member of the base
    base.each do |pred|
      # begin
        # puts 'before unify'
        # puts context.to_s
      ctxs = unify(term, pred.reify, base, context.dup)
        # puts 'prove   ' + ctx.class.name
        # puts ' prove   pred: ' + pred.to_s
      list.concat(ctxs)
      # rescue => e
        # TODO: do something?
        # puts "unification of \n    #{term}\n  with\n    #{pred}\n  FAILED"
        # puts e.to_s
        # puts e.backtrace.to_s
      # end
    end
  end

  return list unless list.empty?

  return [] # TODO: remove this - if list is empty we can just return the list
  # raise 'Prove was unsuccessful.'
end

def unify(left, right, base, context)
  # puts "trying to unify #{left} with #{right}  in the context: #{context}"

  # trivial
  if left == right
    return [context]

  # unify wildcard with anything
  elsif left.is_a?(Wildcard) || right.is_a?(Wildcard)
    return [context]

  # unify two fresh variables
  elsif context.fresh?(left) && context.fresh?(right)
    return [context.fuse(left, right)]

  # unify fresh var and one in Assoc
  # one side
  elsif context.fresh?(left) && context.assocd?(right)
    return [context.assoc2fusassociate(right, left)]
  # oposite side
  elsif context.fresh?(right) && context.assocd?(left)
    return [context.assoc2fusassociate(left, right)]

  # unify fresh var and one fused
  # one side
  elsif context.fresh?(left) && context.fused?(right)
    return [context.fuse(left, right)]
  # opposite side
  elsif context.fresh?(right) && context.fused?(left)
    return [context.fuse(left, right)]

  # unify fresh var and fusasscd one
  # one side
  elsif context.fresh?(left) && context.fusassocd?(right)
    return [context.add2fusassoc(right, left)]
  # opposite side
  elsif context.fresh?(right) && context.fusassocd?(left)
    return [context.add2fusassoc(left, right)]

  # unify a fresh var and non var value
  # one side
  elsif context.fresh?(left) && !right.instance_of?(Var)
    return [context.associate(left, right)]
  # opposite side
  elsif context.fresh?(right) && !left.instance_of?(Var)
    return [context.associate(right, left)]

  # unify a variable associated and a variable fused
  # one side
  elsif context.assocd?(left) && context.fused?(right)
    return [context.assoc_plus_fused(left, right)]
  # opposite side
  elsif context.assocd?(right) && context.fused?(left)
    return [context.assoc_plus_fused(right, left)]

  # unify two fused variables
  elsif context.fused?(left) && context.fused?(right)
    return [context.merge_fused(left, right)]

  # unify fused variable with a non var value
  # one side
  elsif context.fused?(left) && !right.instance_of?(Var)
    return [context.fusassociate(left, right)]
  # other side
  elsif context.fused?(right) && !left.instance_of?(Var)
    return [context.fusassociate(right, left)]

  # unify a variable associated with a value and another value
  # one side
  elsif context.assocd?(left) && !right.instance_of?(Var)
    left_val = context[left]
    return unify(left_val, right, base, context)
  # other side
  elsif context.assocd?(right) && !left.instance_of?(Var)
    right_val = context[right]
    return unify(left, right_val, base, context)

  # unify a variable associated with a value and another one associated with value
  # unify a variable associated with a value and another one fusassciated with a value
  # unify variables fusassociated and associated with some values
  # unify two fusassociated variables
  elsif (context.assocd?(left) && context.assocd?(right)) ||
        (context.assocd?(left) && context.fusassocd?(right)) ||
        (context.assocd?(right) && context.fusassocd?(left)) ||
        (context.fusassocd?(left) && context.assocd?(right)) ||
        (context.fusassocd?(right) && context.assocd?(left)) ||
        (context.fusassocd?(left) && context.fusassocd?(right))
    left_val = context[left]
    right_val = context[right]
    return unify(left_val, right_val, base, context)

  # unify a fused variable with a fusassoced variable
  # one side
  elsif context.fused?(left) && context.fusassocd?(right)
    return [context.fused_plus_fusassocd(left, right)]
  # other side
  elsif context.fused?(right) && context.fusassocd?(left)
    return [context.fused_plus_fusassocd(right, left)]

  # unify a variable fusassociated with a value and another value
  # one side
  elsif context.fusassocd?(left) && !right.instance_of?(Var)
    left_val = context[left]
    return unify(left_val, right, base, context)
  # other side
  elsif context.fusassocd?(right) && !left.instance_of?(Var)
    right_val = context[right]
    return unify(left, right_val, base, context)

  # unify a functor with a Rule
  elsif left.is_a?(Functor) && right.is_a?(Rule)
    # first match the name
    if left.name != right.name
      return []
      # raise 'Cannot unify predicate and fact with different names.'
    end

    # match the number of arguments
    if left.arguments.length != right.arguments.length
      return []
      # raise 'Cannot unify predicate and fact with different arity.'
    end

    # unify every argument with each other
    to_unify = left.arguments.zip(right.arguments)

    contexts = to_unify.reduce([context]) do |ctxts, to_unif|
      l, r = to_unif
      lst = []
      ctxts.each do |ctxt|
        cxs = unify(l, r, base, ctxt)
        lst.concat(cxs)
      end
      lst
    end

    # to_unify.each do |l, r|
    #   context = unify(l, r, base, context)
    # end

    # then prove the body
    # return prove(right.body, base, context)

    lst = []
    contexts.each do |ctxt|
      cxs = prove(right.body, base, ctxt)
      lst.concat(cxs)
    end

    return lst

  # to unify a Predicate with a Predicate
  # two constructors for example
  elsif left.is_a?(Functor) && right.is_a?(Functor)
    # both must have the same name
    # both must have the same arity
    # all corresponding positions must unify
    if left.name != right.name
      return []
      # raise 'Cannot unify predicate and fact with different names.'
    end

    if left.arguments.length != right.arguments.length
      return []
      # raise 'Cannot unify predicate and fact with different arity.'
    end

    # unify every argument with each other
    to_unify = left.arguments.zip(right.arguments)

    contexts = to_unify.reduce([context]) do |ctxts, to_unif|
      l, r = to_unif
      lst = []
      ctxts.each do |ctxt|
        cxs = unify(l, r, base, ctxt)
        lst.concat(cxs)
      end
      lst
    end

    return contexts
    # to_unify = left.arguments.zip(right.arguments)

    # to_unify.each do |l, r|
    #   context = unify(l, r, base, context)
    # end

    # return context
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

  return []
  # raise 'Cannot unify these two things.'
end
