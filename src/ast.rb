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

  def specify(_context, _user_vars)
    self
  end

  def occurs(_var_set, _context)
    false
  end
end

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
    dup_with(@name, renamed_args)
  end

  def occurs(var_set, context)
    @arguments.any? do |arg|
      arg.occurs(var_set, context)
    end
  end
end

# a fact
class Fact < Functor
  def to_s
    "#{@name}(#{@arguments.join(', ')})."
  end

  def dup_with(name, args)
    Fact.new(name, args)
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

  def ==(other)
    other.instance_of?(Atom) && @value == other.value
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
      bind.val.specify(context, user_vars)
    when Fusassoc
      bind.val.specify(context, user_vars)
    when Fused
      Var.new("_100#{bind.set.to_a[0].name.delete_prefix('_')}")
    end
  end

  def occurs(var_set, context)
    # if @name == '_7_R'
    #   puts "\n"
    #   puts "hele hele    self: #{self}   var_set: #{var_set}    context: #{context}"
    #   puts "var_set.include?(self)  #{var_set.include?(self)}"
    #   puts "pripadne context[self]   #{context[self]}"
    #   puts "\n"
    # end

    # if @name == '_3_R'
    #   puts "\n"
    #   puts "hele hele    self: #{self}   var_set: #{var_set}    context: #{context}"
    #   puts "var_set.include?(self)  #{var_set.include?(self)}"
    #   puts "pripadne context[self]   #{context[self]}"
    #   puts "\n"
    # end

    # puts "OCCURS check :::   #{self} . occurs ( #{var_set} , #{context}"
    # navic potrebuju context argument
    # a navic potrebuju checknout, jestli ta promenna, nema Assoc nebo Fusassoc nejakou hodnotu
    # a pokud jo, tak tu hodnotu musim taky otestovat na .occurs na ten samej var_set
    return true if var_set.include?(self)
    # return false

    # puts 'ask me'
    # line = Readline.readline("sleduj\n", true)

    maybe_val = context[self]
    case maybe_val
    when nil
      false
    else
      val = maybe_val
      val.occurs(var_set, context)
    end
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

  def ==(other)
    other.instance_of?(Wildcard)
  end
end

# consists of name and list of patterns as arguments
class Predicate < Functor
  def to_s
    "#{@name}(#{@arguments.join(', ')})"
  end

  def dup_with(name, args)
    Predicate.new(name, args)
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

  def ==(other)
    other.instance_of?(Conjunction) && @left == other.left && @right == other.right
  end
end

# _; _
class Disjunction < AST
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def to_s
    "#{@left}; #{@right}"
  end

  def vars
    @left.vars + @right.vars
  end

  def rename(mapping)
    renamed_left = @left.rename(mapping)
    renamed_right = @right.rename(mapping)
    Disjunction.new(renamed_left, renamed_right)
  end

  def dup
    Disjunction.new(@left.dup, @right.dup)
  end

  def ==(other)
    other.instance_of?(Conjunction) && @left == other.left && @right == other.right
  end
end
