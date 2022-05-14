# frozen_string_literal: true

require 'readline'
require 'set'

require_relative './src/token'
require_relative './src/ast/functor'
require_relative './src/lexer'
require_relative './src/parser'
require_relative './src/context/context'
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

    # export the base to the file
    elsif @line.start_with?(':export') || @line.start_with?(':e')
      @should_skip = true
      filename = @line.delete_prefix(':export').delete_prefix(':e').strip

      if filename.empty?
        puts 'You must specify a file name for the base to be exported to!'
        return
      end

      # serialize and store the base
      content = @knowledge_base.map do |member|
        "#{member}\n"
      end.join
      File.open(filename, 'a') { |file| file.write(content) }

    # import the base from the file
    elsif @line.start_with?(':import') || @line.start_with?(':i')
      @should_skip = true
      filename = @line.delete_prefix(':import').delete_prefix(':i').strip

      if filename.empty?
        puts 'You must specify a file name which should be imported!'
        return
      end

      unless File.exist?(filename)
        puts "The file `#{filename}` does not exist!"
        return
      end

      base = []
      transaction_ok = true

      File.foreach(filename) do |line|
        lexer = Lexer.new(line.strip)
        ast = nil

        # parse
        parser = Parser.new(lexer)
        begin
          ast = parser.execute
        rescue => _e
          puts "There is a syntax error in the file.\nCouldn't parse\n  #{line}"
          transaction_ok = false
          break
        end

        unless ast.instance_of?(Fact) || ast.instance_of?(Rule)
          puts "I can not store this!\n  #{line}\nis not a rule or fact!"
          transaction_ok = false
          break
        end

        base << ast
      end

      @knowledge_base += base if transaction_ok

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
    puts 'You are in the storing/loading mode. Write rules and facts. They will be stored to the knowledge base.'
    puts ''
    puts ':(c)heck   to switch to the checking/querying mode'
    puts ':(s)tore   to switch to the storing/loading mode'
    puts ':show      to show the whole knowledge base'
    puts ':clear     to clear the whole knowledge base'
    puts ':(r)eify   to reify every variable in the given term with unique prefix'
    puts ':(o)ccurs  to enable/disable strict occurs checking'
    puts ':(e)xport  to export current knowledge base into the .pl file'
    puts ':(i)mport  to import existing knwoledge base from the file'
    puts ':(q)uit    to quit the repl'
    puts ''
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

        fiber = @evaluator.prove(ast, @knowledge_base, Context.new)

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
            puts "  False.\n\n"
            break
          end
        end
        @mode = :check

      else
        puts 'Unknown mode!'
      end
    end
  end

  def present(context, var_names)
    vars = var_names.map { |name| Var.new(name) }
    var_set = vars.to_set
    written_lines = 0
    var_names.each do |varname|
      var = Var.new(varname)
      next if context.fresh?(var)

      val = var.specify(context, var_set)
      case val
      when Var
        next unless var_set.include?(val)
      end
      puts "  #{varname} = #{var.specify(context, var_set)}"
      written_lines += 1
    end
    written_lines
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
