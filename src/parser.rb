# frozen_string_literal: true

require_relative './token'
require_relative './ast'

# Parser of the language
class Parser
  def initialize(lexer)
    @lexer = lexer
  end

  def execute
    r = first_of(
      [method(:parse_rule),
       method(:parse_rule_body), # conjuction, term, or disjunction in the future
       method(:parse_variable),
       method(:parse_literal),
       method(:parse_atom)],
      'not a valid term'
    )

    raise 'not a valid term - there`s something extra' if @lexer.has_next?

    r
  end

  private

  # this one propagates the parsing failure
  def do_parse(&block)
    lex = @lexer.clone

    begin
      block.call
    rescue => e
      @lexer = lex.clone
      raise e
    end
  end

  # this one never fails - if it cannot parse, it just restores the lexer state
  def try_parse(&block)
    lex = @lexer.clone

    begin
      block.call
    rescue => _e
      @lexer = lex.clone
    end
  end

  def first_of(parsers, message)
    parsers.each do |parser|
      begin
        return do_parse { parser.call }
      rescue => _e
        next
      end
    end

    raise message
  end

  # axiom/fact | lowerIdent ( ...pattern ) .
  # predicate | lowerIdent ( ...pattern ) :- pattern... .
  # first parse axiom minus dot           OK
  # then try to parse . --> return fact   OK
  # if that fails try to parse :- --> try to parse rule's body including dot        OK
  # if that fails raise         OK
  def parse_rule
    begin
      f = parse_predicate
    rescue => _e
      raise 'not a rule - failed to parse head of the definition'
    end

    tok = @lexer.next_token

    return Fact.new(f.name, f.arguments) if tok.instance_of? Dot

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

    # potrebuju naparsovat neco jako
    # predicate , predicate , predicate ; predicate ; predicate
    # takze prectu `predicate`, pak prectu logickou spojku a pak prectu `predicate`
    # to mi da kompozitni `predicate`, pak teda musim precist spojku a zase predicate
    # takze vlastne, ctu predikaty v cyklu
    # pred cyklem prectu jeden predikat - protoze kazdy rule_body musi obsahovat aspon jeden predikat
    # tim padem mam v `parts` uz jeden predikat
    # v cyklu tim padem zacinam ctenim spojky
    # pak prectu dalsi predikat a vznikne mi z toho novej prvek do parts
    # vsechno ostatni z parts odstranim
    # tim padem dalsi krok bude precist zase spojku a predikat
    # navic kdykoliv ctu spojku, kdyz misto spojky prijde full stop `.`
    # tak proste vratim co je uz v parts - mel by tam byt vdzycky jenom jeden prvek
    # tim padem to nemusi byt pole ale staci promenna

    # parts = []
    term = nil
    try_parse do
      term = parse_predicate
    end

    while true
      right = nil
      tok = @lexer.next_token

      break if tok.instance_of?(Dot)

      if tok.instance_of?(Comma)
        # and
        try_parse do
          right = parse_predicate
        end
        term = Conjunction.new(term, right)
        next
      end

      if tok.instance_of?(Semicolon)
        # or
        try_parse do
          right = parse_predicate
        end
        term = Disjunction.new(term, right)
        next
      end

      # unknown token
      raise 'not a rule - incorrect body'
    end

    term

    # while true
    #   try_parse do
    #     f = parse_predicate
    #     parts << f
    #   end

    #   tok = @lexer.next_token

    #   next if tok.instance_of? Comma

    #   break if tok.instance_of? Dot

    #   raise 'not a rule - incorrect body'
    # end

    # parts.reduce { |left, right| Conjunction.new(left, right)}
  end

  def parse_variable
    tok = @lexer.next_token

    return Var.new(tok.str) if tok.instance_of? Upper_Identifier

    raise 'not a variable'
  end

  def parse_atom
    tok = @lexer.next_token

    return Atom.new(tok.str) if tok.instance_of? Lower_Identifier

    raise 'not a atom'
  end

  def parse_number
    tok = @lexer.next_token

    return NumLit.new(tok.value) if tok.instance_of? Numeral

    raise 'not a number'
  end

  def parse_string
    tok = @lexer.next_token

    return TextLit.new(tok.value) if tok.instance_of? Text

    raise 'not a string'
  end

  def parse_literal
    first_of(
      [method(:parse_number),
       method(:parse_string)],
      'not a literal'
    )
  end

  def parse_wild
    tok = @lexer.next_token

    return Wildcard.new if tok.instance_of? Hole

    raise 'not an wildcard'
  end

  def parse_predicate
    # lowercase ( pattern , ... , pattern )

    tok = @lexer.next_token

    raise 'not a predicate - wrong predicate name' unless tok.instance_of? Lower_Identifier

    name = tok.str

    tok = @lexer.next_token

    raise 'not a predicate - missing opening paren' unless tok.instance_of? Open_Paren

    patterns = []

    while true
      try_parse do
        p = parse_pattern
        patterns << p
      end

      tok = @lexer.next_token

      next if tok.instance_of? Comma

      break if tok.instance_of? Close_Paren

      raise 'not a predicate - possibly missing comma after argument or missing closing parenthesis'
    end

    Predicate.new(name, patterns)
  end

  def parse_pattern
    first_of(
      [method(:parse_predicate),
       method(:parse_wild),
       method(:parse_atom),
       method(:parse_literal),
       method(:parse_variable)],
      'not a pattern'
    )
  end
end
