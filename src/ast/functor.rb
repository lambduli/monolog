# frozen_string_literal: true

require 'set'

require_relative '../context'
require_relative './ast'

# general Functor term
class Functor < AST
  attr_accessor :name, :arguments

  def initialize(name, arguments)
    @name = name
    @arguments = arguments
  end

  def vars
    @arguments.reduce([]) { |acc, arg| acc | arg.vars }
  end

  def rename(mapping)
    renamed_args = @arguments.map { |arg| arg.rename(mapping) }
    dup_with(renamed_args)
  end

  def occurs(var_set, context)
    @arguments.any? do |arg|
      arg.occurs(var_set, context)
    end
  end

  def unsafe_occurs(var_set, context)
    @arguments.any? do |arg|
      arg.unsafe_occurs(var_set, context)
    end
  end
end

# a fact
class Fact < Functor
  def to_s
    "#{@name}(#{@arguments.join(', ')})."
  end

  def dup_with(args)
    Fact.new(@name, args)
  end

  def dup
    Fact.new(@name, @arguments.map { |arg| arg.dup })
  end

  def ==(other)
    other.instance_of?(Fact) && @name == other.name && @arguments == other.arguments
  end

  def specify(context, user_vars)
    Fact.new(@name, @arguments.map { |arg| arg.specify(context, user_vars) })
  end
end

# consists of predicate (head + body) and conjunction ~~or~~disjunctions~~
class Rule < AST
  attr_accessor :name, :arguments, :body

  def initialize(name, arguments, body)
    @name = name
    @arguments = arguments
    @body = body
  end

  def to_s
    "#{@name} (#{@arguments.join(', ')}) :- #{body}."
  end

  def vars
    arg_vars = @arguments.reduce([]) { |acc, arg| acc | arg.vars }
    body_vars = @body.vars
    arg_vars | body_vars
  end

  def rename(mapping)
    renamed_args = @arguments.map { |arg| arg.rename(mapping) }
    renamed_body = @body.rename(mapping)
    Rule.new(@name, renamed_args, renamed_body)
  end

  def dup
    Rule.new(@name, @arguments.dup, @body.dup)
  end

  def ==(other)
    other.instance_of?(Rule) && @arguments == other.arguments && @body == other.body
  end
end

# consists of name and list of patterns as arguments
class Predicate < Functor
  def to_s
    "#{@name}(#{@arguments.join(', ')})"
  end

  def dup_with(args)
    Predicate.new(@name, args)
  end

  def dup
    Predicate.new(@name, @arguments.map{ |arg| arg.dup })
  end

  def ==(other)
    other.instance_of?(Predicate) && @name == other.name && @arguments == other.arguments
  end

  def specify(context, user_vars)
    Predicate.new(@name, @arguments.map { |arg| arg.specify(context, user_vars) })
  end
end

# represents a list cell [head | tail]
class Cons < Predicate
  def initialize(head, tail)
    super('Cons', [head, tail])
  end

  def to_s
    "[#{@arguments[0]} | #{@arguments[1]}]"
  end

  def dup_with(args)
    Cons.new(*args)
  end

  def dup
    Cons.new(*@arguments.map{ |arg| arg.dup })
  end

  def ==(other)
    other.instance_of?(Cons) && @arguments == other.arguments
  end

  def specify(context, user_vars)
    Cons.new(*@arguments.map { |arg| arg.specify(context, user_vars) })
  end
end

# represents an empty list cell []
class Nil < Predicate
  def initialize
    super('Nil', [])
  end

  def to_s
    '[]'
  end

  def dup_with(_args)
    Nil.new
  end

  def dup
    Nil.new
  end

  def ==(other)
    other.instance_of?(Nil)
  end

  def specify(_context, _user_vars)
    Nil.new
  end
end
