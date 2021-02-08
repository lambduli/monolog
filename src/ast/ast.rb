# frozen_string_literal: true

require 'set'

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

  def unsafe_occurs(_var_set, _context)
    false
  end
end
