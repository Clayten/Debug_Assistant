# Capture the variables from the site of an exception and display relevant info
#
# https://stackoverflow.com/questions/7647103/can-i-access-the-binding-at-the-moment-of-an-exception-in-ruby
# https://stackoverflow.com/questions/106920/how-can-i-get-source-and-variable-values-in-ruby-tracebacks

require 'binding_of_caller'

module ExceptionBinding

  module BindingExtension
    refine Binding do
      attr_reader :iseq
    end
  end
  using BindingExtension

  def filtered_files
    %w[\.rubies \.gem (pry)]
  end

  def file_filter
    /#{filtered_files.join('|')}/
    # /^XYZ$/
  end

  def has_backtrace? ; backtrace && !backtrace.empty? end

  def call_history
    backtrace
  end

  def filtered_call_history
    call_history.reject {|bt| bt =~ file_filter }
  end

  def parse_backtrace_line bt
    file, line, method_id = bt.split(':')
    method_name = method_id.scan(/`([^']+)'/).first.first
    [file, line, method_name]
  end

  def methods_from_bindings
    bindings.map {|b| Pry::Method.from_binding b }
  end

  def files_from_bindings ; bindings.map {|c| f,l = c.source_location rescue [:unknown_file, 0] ; f } end

  def filter_common_filename_elements text, filenames = files_from_bindings
    short_names = common_dir_prefix_removal filenames
    file_translation = Hash[filenames.zip(short_names)]
    file_translation.inject(text) {|t, (n, sn)| t.gsub(n, sn) }
  end

  def sites
    return to_enum :sites unless block_given?
    bindings.length.times {|i|
      b = bindings[i]
      m = Pry::Method.from_binding b rescue nil
      c = Pry::Code.from_method m rescue nil
      yield b,m,c
    }
  end

  def code_context_by_stack filter: true, depth: nil
    callers = binding.frame_count.times.map {|n| binding.of_caller n }[1..-1].map(&:iseq)
    out = []
    bindings.each {|binding|
      method = Pry::Method.from_binding binding
      code   = Pry::Code.from_method    method  rescue nil if method
      code   = Pry::Code.from_method    binding rescue nil unless code
      code   = method.source                    rescue nil unless code

      receiver = binding.receiver
      bf, bl = binding.source_location rescue nil
      mf, ml =  method.source_location rescue nil
      sr = method.source_range rescue nil
      lvs = local_variables_at binding

      raise "Invalid lines #{ml} #{bl} #{sr}" if sr && !sr.include?(ml || bl)

      p [:mf, mf]
      next p [:skip, mf] if mf && mf =~ file_filter if filter # skip library files, etc

      out << "#{mf || bf}"
      out << "#{receiver.class} #{receiver}"
      source = code.with_line_numbers.with_marker(bl).to_s if code
      out << "#{source}end" if source && !source.empty?
      unless lvs.empty?
      out << "Local Variables:"
      lvs.each {|k,v| out << "#{'%20s' % k}: #{v.inspect[0...40]}" }
      end
      out << "--------"
      break if callers.include? binding.iseq if filter # break once we get up above the user's code
      if depth
        depth = depth - 1
        break if depth.zero?
      end
    }
    out.join("\n")
  end

  # In file and line order, not by stack depth
  def code_context_by_file
    called_methods_by_file = Hash.new {|h,k| h[k] = Set.new }
    bindings.each {|b|
      f, _ = b.source_location
      m = Pry::Method.from_binding b
      called_methods_by_file[f] << m if m
    }
    context = called_methods_by_file.map {|file, methods|
      next if file =~ file_filter
      receiver = nil
      methods = methods.to_a.sort_by! {|m| m.source_line rescue 0 }
      source = methods.
        map {|method|
          suffix = prefix = nil
          wrapped_method = method.wrapped
          if receiver != method.receiver
            klass = method.receiver.class
            close_if_needed = ['end',''] unless receiver.nil?
            prefix = "#{klass.to_s.downcase} #{method.receiver}"
            receiver = method.receiver
          end
          code = Pry::Code.from_method(method) rescue (next p [:NoCode!])
          source = code.with_line_numbers.to_s.rstrip.gsub(/^\s*(\d+):/) {|n| '% 4s' % n.strip }
          [close_if_needed, prefix, source, ''].flatten.compact
        }
      suffix_if_needed = 'end' if receiver
      [file, source.flatten, suffix_if_needed].compact.join("\n")
    }.compact.join("\n\n").gsub(/(\d+:.*end\n)\nend/) {|s| s.gsub("\n\n", "\n") }
    filter_common_filename_elements context
  end

  def strip_ansi txt ; txt.dup.gsub(/\e\[(\d+(;\d+(;\d+)?)?)?./,'') end

  def filtered_full_message
    msg = strip_ansi(full_message)
    lines = msg.lines
    msg = [lines.first] +
      lines[1..-1].
      reject {|l| l =~ file_filter }.
      reject {|l| l =~ /^\s*\^+$/ }.
      reject {|l| l.strip.empty? }
    filter_common_filename_elements msg.join
  end

  def common_dir_prefix_removal files
    file_parts = files.map {|file| file.split('/').reject(&:empty?) }
    return [file_parts.first.last(2).join('/')] if files.length == 1
    shortest = file_parts.map(&:length).min
    common = shortest.times.find {|n| file_parts.map {|parts| parts[n] }.uniq.length != 1 }
    start = common.zero? ? 0 : common - 1
    file_parts.map {|parts| File.join *parts[start .. -1] }
  end

  def problem
    filtered_full_message + "\n" + code_context_by_stack
  end

  def local_variable_filter ; /(^_|pry_instance)/ end
  def local_variables_at b
    Hash[b.local_variables.map {|k| v = b.local_variable_get k ; next if k =~ local_variable_filter ; [k,v]}.compact]
  end

  def local_vars_at_exception ; local_variables_at bindings.first end

  def custom_types_at_exception
    local_vars_at_exception.
      map {|n,v| m = v.is_a?(Module) ? v : v.class }.
      reject {|m| m == NilClass }.
      map {|m|
        next unless c = Pry::Code.from_module(m) rescue nil
        c.with_line_numbers
      }.compact.map(&:to_s)
  end

  attr_reader :bindings
  # def initialize *a
  #   @foo = 42
  #   p [:init, self.class, a]
  #   super
  #   @bindings = binding.callers[1..-1]
  # end

  def set_callers bnds ; @bindings = bnds end
end
#class StandardError < Exception ; include ExceptionBinding end
#class NoMethodError < NameError ; include ExceptionBinding end
class Exception

  include ExceptionBinding

  def self.enable_debugging
    @tp ||= TracePoint.new(:raise) {|tp|
      $e = e = tp.raised_exception
      e.set_callers binding.callers[1..-1]
    }
    @tp.enable 
  end
  def self.disable_debugging
    @tp.disable if @tp
    @tp = nil
  end
  def self.tp ; @tp end
end
