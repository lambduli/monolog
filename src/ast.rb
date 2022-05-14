# frozen_string_literal: true

require_relative './context'

# general AST
class AST
  def vars
    []
  end
end

# general Functor term
class Functor < AST
  attr_accessor :name, :arguments

  def initialize(name, arguments)
    @name = name
    @arguments = arguments
  end
end

# a fact
class Fact < Functor
  def to_s
    @name + '(' + @arguments.join(', ') + ').'
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
end

# Literals like strings and numbers
class Literal < AST
  attr_accessor :value # later make it protected

  def initialize(value)
    @value = value
  end
end

# numeric literal
class NumLit < Literal
  def to_s
    @value.to_s
  end
end

# text literal
class TextLit < Literal
  def to_s
    "\"#{@value}\""
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
end

# _
class Wildcard < AST
  def to_s
    '_'
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
end

# _, _
class Conjunction < AST
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def to_s
    @left.to_s + ', ' + @right.to_s
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
