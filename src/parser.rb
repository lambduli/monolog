# frozen_string_literal: true

require_relative './token.rb'
require_relative './ast.rb'



class Parser

  def initialize(lexer)
    @lexer = lexer
  end

  def parse
    lex = @lexer.clone

    begin
      # axiom/fact
      # predicate, query
      r = parse_rule
      if @lexer.has_next?
        raise 'not a valid rule - there`s something extra'
      end
      return r
    rescue => e
      @lexer = lex.clone
    end

    begin
      v = parse_variable
      if @lexer.has_next?
        raise 'not a valid variable - there`s something extra'
      end
      return v
    rescue => e
      @lexer = lex.clone
    end

    begin
      l = parse_literal
      if @lexer.has_next?
        raise 'not a valid literal - there`s something extra'
      end
      return l
    rescue => _e
      @lexer = lex.clone
    end

    begin
      a = parse_atom
      if @lexer.has_next?
        raise 'not a valid atom - there`s something extra'
      end
      return a
    rescue => _e
      @lexer = lex.clone
    end

    raise 'failed to parse the term'
  end

  private

  # OK
  def parse_rule
    # axiom/fact | lowerIdent ( ...pattern ) .
    # predicate | lowerIdent ( ...pattern ) :- pattern... .
    # first parse axiom minus dot           OK
    # then try to parse . --> return fact   OK
    # if that fails try to parse :- --> try to parse rule's body including dot        OK
    # if that fails raise         OK

    lex = @lexer.clone

    begin
      f = parse_predicate
    rescue => _e
      raise 'not a rule - failed to parse head of the definition'
    end

    tok = @lexer.next_token
    if tok.instance_of? Dot
      return Fact.new(f.name, f.arguments)
    end

    if tok.instance_of? If
      begin
        b = parse_rule_body
        return Rule.new(f.name, f.arguments, b)
      rescue => _e
        raise 'not a rule - failed to parse the body of the definition'
      end
    end

    raise 'not a rule or fact - missing either . or :-'
  end

  def parse_rule_body
    # it also parses the dot at the end
    # sequence of Predicate, Is_Unif
    # first version just conjunctions
    # it can be either functor/predicate or IS arithmetic expression
    # let's start with functors

    parts = []

    while true do
      lex = @lexer.clone

      begin
        f = parse_predicate
        parts << f
      rescue => _e
        @lexer = lex.clone
      end

      tok = @lexer.next_token

      if tok.instance_of? Comma
        next
      end

      if tok.instance_of? Dot
        break
      end

      raise 'not a rule - incorrect body'
    end

    parts.reduce { |left, right| Conjunction.new(left, right)}
  end

  # OK
  def parse_variable
    tok = @lexer.next_token

    if tok.instance_of? Upper_Identifier
      Var.new(tok.str)
    else
      raise 'not a variable'
    end
  end

  # OK
  def parse_atom
    tok = @lexer.next_token

    if tok.instance_of? Lower_Identifier
      Atom.new(tok.str)
    else
      raise 'not a atom'
    end
  end

  # OK
  def parse_number
    tok = @lexer.next_token

    if tok.instance_of? Numeral
      Literal.new(tok.value)
    else
      raise 'not a number'
    end
  end

  # OK
  def parse_string
    tok = @lexer.next_token

    if tok.instance_of? Text
      Literal.new(tok.value)
    else
      raise 'not a string'
    end
  end

  def parse_literal
    lex = @lexer.clone

    begin
      n = parse_number
      return n
    rescue => _e
      @lexer = lex.clone
    end

    begin
      s = parse_string
      return s
    rescue => _e
      @lexer = lex.clone
    end

    raise 'not a literal'
  end

  # OK
  def parse_wild
    tok = @lexer.next_token

    if tok.instance_of? Hole
      Wildcard.new
    else
      raise 'not an wildcard'
    end
  end

  # OK
  def parse_predicate
    # lowercase ( pattern , ... , pattern )

    tok = @lexer.next_token

    if !tok.instance_of? Lower_Identifier
      raise 'not a predicate - wrong predicate name'
    end

    name = tok.str

    tok = @lexer.next_token

    if !tok.instance_of? Open_Paren
      raise 'not a predicate - missing opening paren'
    end

    patterns = []

    while true do
      lex = @lexer.clone

      begin
        p = parse_pattern
        patterns << p
      rescue => _e
        @lexer = lex.clone
      end

      tok = @lexer.next_token

      if tok.instance_of? Comma
        next
      end

      if tok.instance_of? Close_Paren
        break
      end

      raise 'not a predicate - possibly missing comma after argument or missing closing parenthesis'
    end

    Predicate.new(name, patterns)
  end

  # OK
  def parse_pattern
    lex = @lexer.clone

    # predicate
    begin
      p = parse_predicate
      return p
    rescue => _e
      @lexer = lex.clone
    end

    # _
    begin
      w = parse_wild
      return w
    rescue => _e
      @lexer = lex.clone
    end

    # atom
    begin
      a = parse_atom
      return a
    rescue => _e
      @lexer = lex.clone
    end

    # literal
    begin
      l = parse_literal
      return l
    rescue => _e
      @lexer = lex.clone
    end

    # variable
    begin
      v = parse_variable
      return v
    rescue => _e
      @lexer = lex.clone
    end

    # nebo list destructuring -- later

    raise 'not a pattern'
  end
end
