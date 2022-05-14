# frozen_string_literal: true

require_relative './token.rb'


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
    @input.size != 0
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
      r = Hole.new(@row, @col)
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
      r = Cons.new(@row, @col)
      @col += 1
      r

    when '+'
      r = Operator.new(char, @row, @col)
      @col += 1
      r
    when '-'
      r = Operator.new(char, @row, @col)
      @col += 1
      r
    when '*'
      r = Operator.new(char, @row, @col)
      @col += 1
      r
    when '/'
      r = Operator.new(char, @row, @col)
      @col += 1
      r
    when '"'
      readString

    when 'i'
      if @input[0] == 's' && @input[1] == ' '
        r = Is.new(@row, @col)
        @col += 3
        @input = @input.drop 2
        r
      else
        @col += 1
        readLowerIdentifier('i')
      end
    when ':'
      if @input[0] == '-' && @input[1] == ' '
        r = If.new(@row, @col)
        @col += 3
        @input = @input.drop 2
        r
      else
        raise 'Invalid token at line ' + @row + ' column ' + @col
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
        raise 'Unknown character ' + char + ' at line ' + @row + ' column ' + @col
      end
    end
  end

  private

  def readLowerIdentifier(leading)
    if @input.empty?
      return Lower_Identifier.new(leading, @row, @col)
    end

    char, *@input = @input

    case char
    when ' '
      r = Lower_Identifier.new(leading, @row, @col)
      @col += 1
      r
    else
      if (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
        r = readLowerIdentifier(leading + char)
        @col += 1
        r
      else
        r = Lower_Identifier.new(leading, @row, @col)
        @input = @input.prepend char
        r
      end
    end
  end

  def readUpperIdentifier(leading)
    if @input.empty?
      return Upper_Identifier.new(leading, @row, @col)
    end

    char, *@input = @input

    case char
    when ' '
      r = Upper_Identifier.new(leading, @row, @col)
      @col += 1
      r
    else
      if (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
        r = readUpperIdentifier(leading + char)
        @col += 1
        r
      else
        r = Upper_Identifier.new(leading, @row, @col)
        @input = @input.prepend char
        r
      end
    end
  end

  def readNumber(leading)
    if @input.empty?
      return Numeral.new(leading.to_i, @row, @col)
    end

    char, *@input = @input

    if char >= '0' && char <= '9'
      r = readNumber(leading + char)
      @col += 1
      r
    else
      r = Numeral.new(leading.to_i, @row, @col)
      @input = @input.prepend char
      r
    end
  end

  def readString
    if @input.empty?
      raise 'missing ending "'
    end

    r = @row
    c = @col

    @col += 1

    char, *@input = @input
    @col += 1
    chars = []

    while char != '"' do
      chars.append(char)

      if @input.empty?
        raise 'missing ending "'
      end
      char, *@input = @input
      @col += 1
    end

    Text.new(chars.join(''), r, c)
  end


  protected

  attr_accessor :row, :col
end
