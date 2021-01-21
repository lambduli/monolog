# frozen_string_literal: true

require_relative './context'

# general AST
class AST
  @@counter = 0
  def reify
    vars = self.vars
    mapping = vars.reduce({}) { |acc, var| acc.merge({ var => "_#{get_index}_#{var}" }) }
    rename(mapping)
  end

  # protected

  def vars
    []
  end

  def rename(_mapping)
    self
  end

  def get_index
    old = @@counter
    @@counter += 1
    old
  end
end

# general Functor term
class Functor < AST
  attr_accessor :name, :arguments

  def initialize(name, arguments)
    @name = name
    @arguments = arguments
  end

  # protected

  def vars
    @arguments.reduce([]) { |acc, arg| acc | arg.vars }
  end

  def rename(mapping)
    renamed_args = @arguments.map { |arg| arg.rename(mapping) }
    dup_with(@name, renamed_args)
  end
end

# a fact
class Fact < Functor
  def to_s
    @name + '(' + @arguments.join(', ') + ').'
  end

  def dup_with(name, args)
    Fact.new(name, args)
  end

  def dup
    Fact.new(@name, @args.map { |arg| arg.dup })
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
    @name + '(' + @arguments.join(', ') + ') :- ' + body.to_s + '.'
  end

  # protected

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
end

# atoms are special terms
class Atom < AST
  attr_accessor :value # later make it protected

  def initialize(value)
    @value = value
  end

  def to_s
    @value
  end

  def dup
    Atom.new(@value)
  end
end

# Literals like strings and numbers
class Literal < AST
  attr_accessor :value # later make it protected

  def initialize(value)
    @value = value
  end

  def ==(other)
    eq?(other)
  end
end

# numeric literal
class NumLit < Literal
  def to_s
    @value.to_s
  end

  def eq?(other)
    other.instance_of?(NumLit) && @value == other.value
  end

  def dup
    NumLit.new(@value)
  end
end

# text literal
class TextLit < Literal
  def to_s
    "\"#{@value}\""
  end

  def eq?(other)
    other.instance_of?(TextLit) && @value == other.value
  end

  def dup
    TextLit.new(@value)
  end
end

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
    @name == other.name
  end

  # protected

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
end

# _
class Wildcard < AST
  def to_s
    '_'
  end

  def dup
    Wildcard.new
  end
end

# TODO: implement later
# class ListPattern < Pattern
# end

# consists of name and list of patterns as arguments
class Predicate < Functor
  def to_s
    @name + '(' + @arguments.join(', ') + ')'
  end

  def dup_with(name, args)
    Predicate.new(name, args)
  end

  def dup
    Predicate.new(@name, @args.map{ |arg| arg.dup })
  end
end

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

  # protected

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
end

# _; _
# class Disjunction < AST
#   attr_accessor :left, :right

#   def initialize(left, right)
#     super
#     @left = left
#     @right = right
#   end

#   def to_s
#     @left.to_s + '; ' + @right.to_s
#   end
# end

# Var is 23
# class Is_Unif < AST
# end

# class Operation < AST

# end
