# frozen_string_literal: true

require_relative './token'

# Lexer of the language
class Lexer
  def initialize(input)
    @input = input.chars
    @row = 0
    @col = 0
  end

  def clone
    l = Lexer.new(@input.join(''))
    l.row = @row
    l.col = @col
    l
  end

  def has_next?
    !@input.empty?
  end

  def next_token
    char, *@input = @input

    case char
    when "\n"
      @row += 1
      @col = 0
      next_token
    when ' '
      @col += 1
      next_token
    when '_'
      r = Underscore.new(@row, @col)
      @col += 1
      r
    when '('
      r = Open_Paren.new(@row, @col)
      @col += 1
      r
    when ')'
      r = Close_Paren.new(@row, @col)
      @col += 1
      r
    when '['
      r = Open_Bracket.new(@row, @col)
      @col += 1
      r
    when ']'
      r = Close_Bracket.new(@row, @col)
      @col += 1
      r
    when ','
      r = Comma.new(@row, @col)
      @col += 1
      r
    when ';'
      r = Semicolon.new(@row, @col)
      @col += 1
      r
    when '.'
      r = Dot.new(@row, @col)
      @col += 1
      r
    when '|'
      r = Pipe.new(@row, @col)
      @col += 1
      r

    when '"'
      readString

    when ':'
      if @input[0] == '-' && @input[1] == ' '
        r = If.new(@row, @col)
        @col += 3
        @input = @input.drop 2
        r
      else
        raise "Invalid token at line #{@row} column #{@col}"
      end
    when '\\'
      if @input[0] == '+' && @input[1] == ' '
        r = SlashPlus.new(@row, @col)
        @col += 3
        @input = @input.drop 2
        r
      else
        raise "Invalid token at line #{@row} column #{@col}"
      end
    else
      if char >= 'a' && char <= 'z'
        @col += 1
        readLowerIdentifier(char)
      elsif char >= 'A' && char <= 'Z'
        @col += 1
        readUpperIdentifier(char)
      elsif char >= '0' && char <= '9'
        @col += 1
        readNumber(char)
      else
        raise "Unknown character #{char} at line #{@row} column #{@col}"
      end
    end
  end

  private

  def readLowerIdentifier(leading)
    return Lower_Identifier.new(leading, @row, @col) if @input.empty?

    char, *@input = @input

    case char
    when ' '
      r = Lower_Identifier.new(leading, @row, @col)
      @col += 1
    else
      if (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
        r = readLowerIdentifier(leading + char)
        @col += 1
      else
        r = Lower_Identifier.new(leading, @row, @col)
        @input.prepend char
      end
    end
    r
  end

  def readUpperIdentifier(leading)
    return Upper_Identifier.new(leading, @row, @col) if @input.empty?

    char, *@input = @input

    case char
    when ' '
      r = Upper_Identifier.new(leading, @row, @col)
      @col += 1
    else
      if (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
        r = readUpperIdentifier(leading + char)
        @col += 1
      else
        r = Upper_Identifier.new(leading, @row, @col)
        @input.prepend char
      end
    end
    r
  end

  def readNumber(leading)
    return Numeral.new(leading.to_i, @row, @col) if @input.empty?

    char, *@input = @input

    if char >= '0' && char <= '9'
      r = readNumber(leading + char)
      @col += 1
    else
      r = Numeral.new(leading.to_i, @row, @col)
      @input.prepend char
    end
    r
  end

  def readString
    raise 'missing ending "' if @input.empty?

    r = @row
    c = @col

    @col += 1

    char, *@input = @input
    @col += 1
    chars = []

    while char != '"'
      chars.append(char)

      raise 'missing ending "' if @input.empty?

      char, *@input = @input
      @col += 1
    end

    Text.new(chars.join(''), r, c)
  end

  protected

  attr_accessor :row, :col
end
