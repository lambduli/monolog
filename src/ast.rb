# frozen_string_literal: true

require_relative './context'

class AST
  def vars
    []
  end
end


class Functor < AST
  attr_accessor :name, :arguments
  def initialize(name, arguments)
    @name = name
    @arguments = arguments
  end
end


class Fact < Functor
  def to_s
    @name + '(' + @arguments.join(', ') + ').'
  end
end


# consists of predicate and conjunction ~~or~~disjunctions~~
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

  def to_s
    @value.to_s
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


# class Is_Unif < AST
# end

# class Operation < AST

# end
