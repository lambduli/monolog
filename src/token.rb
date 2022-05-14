# frozen_string_literal: true

# abstract predecessor of all tokens
class Token
end

# x...
class Lower_Identifier < Token
  attr_accessor :str, :row, :column

  def initialize(str, row, column)
    @str = str
    @row = row
    @column = column
  end
end

# X...
class Upper_Identifier < Token
  attr_accessor :str, :row, :column

  def initialize(str, row, column)
    @str = str
    @row = row
    @column = column
  end
end

# [
class Open_Bracket < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# ]
class Close_Bracket < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# (
class Open_Paren < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# )
class Close_Paren < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# ,
class Comma < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# ;
class Semicolon < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# .
class Dot < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# |
class Cons < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# + * / -
class Operator < Token
  attr_accessor :op, :row, :column

  def initialize(op, row, column)
    @op = op
    @row = row
    @column = column
  end
end

# is
class Is < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# :-
class If < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end

# 123
class Numeral < Token
  attr_accessor :value, :row, :column

  def initialize(value, row, column)
    @value = value
    @row = row
    @column = column
  end
end

# "text"
class Text < Token
  attr_accessor :value, :row, :column

  def initialize(value, row, column)
    @value = value
    @row = row
    @column = column
  end
end

# _
class Underscore < Token
  attr_accessor :row, :column

  def initialize(row, column)
    @row = row
    @column = column
  end
end
