# frozen_string_literal: true

require 'readline'

require_relative './src/token'
require_relative './src/ast'
require_relative './src/lexer'
require_relative './src/parser'
require_relative './src/context'
require_relative './src/evaluate'

# REPL
class REPL
  def initialize
    @knowledge_base = []
    @mode = :store
    @should_quit = false
    @should_skip = false
    @line = nil
  end

  def prompt
    case @mode
    when :check
      '?- '
    when :store
      '!- '
    when :reify
      '_- '
    else '> '
    end
  end

  def process_commands
    if @line.start_with?(':quit') || @line.start_with?(':q')
      @should_quit = true

    # reify the term
    elsif @line.start_with?(':reify') || @line.start_with?(':r')
      @mode = :reify
      @should_skip = true

    elsif @line.empty?
      @should_skip = true

    elsif @line.start_with?(':clear')
      @knowledge_base = []
      @should_skip = true

    # switch to checking mode
    elsif @line.start_with?(':check') || @line.start_with?(':c')
      @mode = :check
      @should_skip = true

    elsif @line.start_with?(':show')
      @knowledge_base.each do |member|
        puts "   #{member}"
      end
      @should_skip = true

    # switch to storing mode
    elsif @line.start_with?(':store') || @line.start_with?(':s')
      @mode = :store
      @should_skip = true

    # unknown command
    elsif @line.start_with?(':')
      puts 'Unknown command, please repeat.'
      @should_skip = true

    else
      @should_skip = false
    end
  end

  def run
    system 'clear'
    puts 'Monolog - implementation of simple logic programming language.'
    puts 'You are in the loading mode. Write rules and facts. They will be stored to the knowledge base.'
    puts ''
    puts ':(c)heck   to switch to querying mode'
    puts ':(s)tore   to switch to loading mode'
    puts ':show      to show the whole knowledge base'
    puts ':clear     to clear the whole knowledge base'
    puts ':(r)eify   to reify every variable in the given term with unique prefix'
    puts ':(q)uit    to quit the repl'
    puts ''
    # input = 'isSmall(X, _, small(some(atom, [1 | T]))) :- someMagic(X, V), E is [2 | 3 | [23]] ; other(V, E).'
    while true
      # Read
      @line = Readline.readline(prompt, true)

      process_commands

      if @should_quit
        puts 'bye'
        return
      end

      next if @should_skip

      lexer = Lexer.new(@line)

      # parse
      parser = Parser.new(lexer)
      begin
        ast = parser.execute
      rescue => _e
        puts "Couldn't parse that."
        next
      end

      case @mode
      when :store
        unless ast.instance_of?(Fact) || ast.instance_of?(Rule)
          puts 'I can not store this! Must be a Rule or a Fact.'
          next
        end

        @knowledge_base << ast

      when :reify
        reified = ast.reify
        puts "   #{reified}"

      when :check
        ast = Predicate.new(ast.name, ast.arguments) if ast.instance_of? Fact

        begin
          context = prove(ast, @knowledge_base, Context.new)
          vars = ast.vars
          puts "\n"
          present(context, vars)
          # puts context.to_s
        rescue => _e
          # puts e.to_s
          puts "\n    False."
        end
      else
        puts 'unknown mode'
      end
    end
  end

  def present(context, var_set)
    var_set.each do |var|
      puts "  #{var} = #{Var.new(var).specify(context, var_set)}"
    end
  end
end

REPL.new.run
