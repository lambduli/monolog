#frozen_string_literal: true

require_relative './context'

def prove(term, base, context)
  case term
  when Conjunction
    ctx = prove(term.left, base, context)
    return prove(term.right, base, ctx)
  else
    # iterate base and try to unify term with each member of the base
    base.each do |pred|
      begin
        # puts 'before unify'
        # puts context.to_s
        ctx = unify(term, pred.reify, base, context.dup)
        # puts 'prove   ' + ctx.class.name
        # puts ' prove   pred: ' + pred.to_s
        return ctx
      rescue => _e
        # TODO: do something?
        # puts "unification of \n    #{term}\n  with\n    #{pred}\n  FAILED"
        # puts e.to_s
        # puts e.backtrace.to_s
      end
    end
  end

  raise 'Prove was unsuccessful.'
end

def unify(left, right, base, context)
  # puts "trying to unify #{left} with #{right}  in the context: #{context}"

  # trivial
  if left == right
    return context

  # # to unify two atoms
  # elsif left.is_a?(Atom) && right.is_a?(Atom) && left.value == right.value
  #   return context
  # # to unify two literals
  # elsif left.is_a?(Literal) && right.is_a?(Literal) && left.value == right.value
  #   return context

  # unify wildcard with anything
  elsif left.is_a?(Wildcard) || right.is_a?(Wildcard)
    return context

  # unify two fresh variables
  elsif context.fresh?(left) && context.fresh?(right)
    return context.fuse(left, right)

  # unify fresh var and one in Assoc
  # one side
  elsif context.fresh?(left) && context.assocd?(right)
    return context.assoc2fusassociate(right, left)
  # oposite side
  elsif context.fresh?(right) && context.assocd?(left)
    return context.assoc2fusassociate(left, right)

  # unify fresh var and one fused
  # one side
  elsif context.fresh?(left) && context.fused?(right)
    return context.fuse(left, right)
  # opposite side
  elsif context.fresh?(right) && context.fused?(left)
    return context.fuse(left, right)

  # unify fresh var and fusasscd one
  # one side
  elsif context.fresh?(left) && context.fusassocd?(right)
    return context.add2fusassoc(right, left)
  # opposite side
  elsif context.fresh?(right) && context.fusassocd?(left)
    return context.add2fusassoc(left, right)

  # unify a fresh var and non var value
  # one side
  elsif context.fresh?(left) && !right.instance_of?(Var)
    return context.associate(left, right)
  # opposite side
  elsif context.fresh?(right) && !left.instance_of?(Var)
    return context.associate(right, left)

  # unify a variable associated and a variable fused
  # one side
  elsif context.assocd?(left) && context.fused?(right)
    return context.assoc_plus_fused(left, right)
  # opposite side
  elsif context.assocd?(right) && context.fused?(left)
    return context.assoc_plus_fused(right, left)

  # unify two fused variables
  elsif context.fused?(left) && context.fused?(right)
    return context.merge_fused(left, right)

  # unify fused variable with a non var value
  # one side
  elsif context.fused?(left) && !right.instance_of?(Var)
    return context.fusassociate(left, right)
  # other side
  elsif context.fused?(right) && !left.instance_of?(Var)
    return context.fusassociate(right, left)

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
    return context.fused_plus_fusassocd(left, right)
  # other side
  elsif context.fused?(right) && context.fusassocd?(left)
    return context.fused_plus_fusassocd(right, left)

  # unify a variable fusassociated with a value and another value
  # one side
  elsif context.fusassocd?(left) && !right.instance_of?(Var)
    left_val = context[left]
    return unify(left_val, right, base, context)
  # other side
  elsif context.fusassocd?(right) && !left.instance_of?(Var)
    right_val = context[right]
    return unify(left, right_val, base, context)

  # Following code hase been fixed and replaced
  # # to unify a fresh variable with anything - left
  # elsif (left.is_a?(Var) && context.fresh?(left)) || (right.is_a?(Var) && context.fresh?(right))
  #   # just the fact that one of them is a fresh variable
  #   # should guarantee this won't fail
  #   return context.bind(left, right)

  # Following code hase been fixed and replaced - hopefuly
  # to unify a Assoc, or Fusassoc Variable with a Functor
  # left var
  # elsif left.is_a?(Var) && context.has_value?(left) && right.is_a?(Functor)
  #   return unify(context[left], right, base, context)
  # # right var
  # elsif right.is_a?(Var) && context.has_value?(right) && left.is_a?(Functor)
  #   return unify(left, context[right], base, context)

  # Following code hase been fixed and replaced - hopefuly
  # to unify a variable with anything except struct
  # elsif left.is_a?(Var)
  #   return context.bind(left, right)
  # elsif right.is_a?(Var)
  #   return context.bind(right, left)

  # unify a functor with a Rule
  elsif left.is_a?(Functor) && right.is_a?(Rule)
    # first match the name
    if left.name != right.name
      raise 'Cannot unify predicate and fact with different names.'
    end

    # match the number of arguments
    if left.arguments.length != right.arguments.length
      raise 'Cannot unify predicate and fact with different arity.'
    end

    # unify every argument with each other
    to_unify = left.arguments.zip(right.arguments)

    to_unify.each do |l, r|
      context = unify(l, r, base, context)
    end

    # then prove the body
    return prove(right.body, base, context)

  # to unify a Predicate with a Predicate
  # two constructors for example
  elsif left.is_a?(Functor) && right.is_a?(Functor)
    # both must have the same name
    # both must have the same arity
    # all corresponding positions must unify
    if left.name != right.name
      raise 'Cannot unify predicate and fact with different names.'
    end

    if left.arguments.length != right.arguments.length
      raise 'Cannot unify predicate and fact with different arity.'
    end

    to_unify = left.arguments.zip(right.arguments)

    to_unify.each do |l, r|
      context = unify(l, r, base, context)
    end

    return context

  # to unify a Predicate with a Fact
  # elsif left.is_a?(Predicate) && right.is_a?(Fact)
  #   # both must have the same name
  #   # both must have the same arity
  #   # all corresponding positions must unify
  #   if left.name != right.name
  #     raise 'Cannot unify predicate and fact with different names.'
  #   end
  #   if left.arguments.length != right.arguments.length
  #     raise 'Cannot unify predicate and fact with different arity.'
  #   end

  #   to_unify = left.arguments.zip(right.arguments)

  #   to_unify.each do |l, r|
  #     context = unify(l, r, base, context)
  #   end

  #   return context
  end

  # to unify a Predicate with a Rule
  # puts "failed to unify #{left} with #{right}  in the context: #{context}"
  # puts 'neco jsem pokazil'
  # puts "left class #{left.class.name}  right class #{right.class.name}   left value #{left}   right value #{right}"
  # puts "#{context.fresh?(left)} && #{context.assocd?(right)}"

  raise 'Cannot unify these two things.'
end
