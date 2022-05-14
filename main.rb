# frozen_string_literal: true

require 'readline'
require 'set'

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
    @evaluator = Evaluator.new(true)
  end

  def prompt
    case @mode
    when :check
      '?- '
    when :store
      '!- '
    when :reify
      '_- '
    when :backtracking
      '@- '
    else '> '
    end
  end

  def process_commands
    if @line.start_with?(':quit') || @line.start_with?(':q') || @line.start_with?(':Q')
      @should_quit = true

    elsif @line.start_with?(':o') || @line.start_with?(':occurs')
      @evaluator.occurs = !@evaluator.occurs
      puts "Strict occurs check #{@evaluator.occurs ? 'enabled' : 'disabled'}."
      @should_skip = true

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
    puts ':(o)ccurs  to enable/disable strict occurs checking'
    puts ':(q)uit    to quit the repl'
    puts ''
    # input = 'isSmall(X, _, small(some(atom, [1 | T]))) :- someMagic(X, V), E is [2 | 3 | [23]] ; other(V, E).'
    while true
      # Read
      @line = Readline.readline(prompt, true)

      process_commands

      if @should_quit
        puts "\nBye!"
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
        @mode = :backtracking

        # contexts = prove(ast, @knowledge_base, Context.new)
        fiber = @evaluator.prove(ast, @knowledge_base, Context.new)
        # ted je potreba ten fiber resumovat tak dlouho, dokud nevrati UnificationFail/False
        # kdykoliv vrati context -> vyprezentuju ten context uzivateli
        #     a cekam jestli uzivatel vlozi prikaz :next nebo :done
        #     na :next pokracuju, na :done skoncim
        # jakmile vrati False -> vypisu False. a skoncim

        puts "\n"
        vars = ast.vars

        while true
          unif_result = fiber.resume

          case unif_result
          when Context
            ctx = unif_result

            lines = present(ctx, vars)
            puts '  True' if lines.zero?

            puts "\n"
            case read_command
            when :next
              puts "\n"
              next
            when :done
              break
            end

            puts "\nor\n\n"
          else
            # puts unif_result.to_s
            puts "  False.\n\n"
            break
          end
        end
        @mode = :check

        # vars = ast.vars
        # puts "\n"
        # contexts.each do |ctxt|
        #   lines = present(ctxt, vars)
        #   puts '  True' if lines.zero?

        #   puts "\nor\n\n"
        # end
        # puts "  False.\n\n"
      else
        puts 'Unknown mode!'
      end
    end
  end

  def present(context, var_names)
    vars = var_names.map { |name| Var.new(name) }
    var_set = vars.to_set
    var_names.each do |var|
      val = Var.new(var).specify(context, var_set)
      case val
      when Var
        next unless var_set.include?(val)
      end
      puts "  #{var} = #{Var.new(var).specify(context, var_set)}"
    end
    var_set.length
  end

  def read_command
    line = Readline.readline(prompt, true)

    if line.start_with?(':n') || line.start_with?(':next')
      :next
    elsif line.start_with?(':d') || line.start_with?(':done')
      :done
    else
      puts 'Unknown command, please repeat.'
      read_command
    end
  end
end

REPL.new.run
