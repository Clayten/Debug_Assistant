# Capture the variables from the site of an exception and display relevant info
#
# https://stackoverflow.com/questions/7647103/can-i-access-the-binding-at-the-moment-of-an-exception-in-ruby
# https://stackoverflow.com/questions/106920/how-can-i-get-source-and-variable-values-in-ruby-tracebacks
#

module ExceptionBinding
  def filtered_files
    %w[\.rubies \.gem (pry)]
  end

  def file_filter
    /#{filtered_files.join('|')}/
  end

  def filtered_backtrace
    (backtrace || []).reject {|bt| bt =~ file_filter }
  end

  def filtered_caller
    caller[1..-1].reject {|bt| bt =~ file_filter }
  end

  def call_history
    # backtrace || caller[2..-1]
    stop_trace if backtrace
    (backtrace && !backtrace.empty?) ? filtered_backtrace : filtered_caller
  end

  def filtered_call_history
    call_history.reject {|bt| bt =~ file_filter }
  end

  def backtrace_sites
    bts = {}
    filtered_call_history.map {|line|
      file, line, method_id = line.split(':')
      method = method_id.scan(/`([^']+)'/).first.first
      [file, line, method]
      bts[[file, line.to_i]] = method
    }
    bts
  end

  def bindings_by_file ; @bindings_by_file ||= Hash.new {|h,k| h[k] = [] } end

  def bindings ; bindings_by_file.values.inject(&:+).map(&:last) end

  def methods_from_bindings
    Hash[bindings.map {|b| m = Pry::Method.from_binding b ; [m.source_location, m]}].values
  end

  def called_methods_by_file
    lines_with_backtraces = backtrace_sites.inject(Hash.new {|h,k| h[k] = [] }) {|h,((f,l),m)| h[f] << l ; h }
    methods_by_file = methods_from_bindings.inject(Hash.new {|h,k| h[k] = [] }) {|h,m| h[m.source_file] << m ; h }
    Hash[methods_by_file.map {|file, methods|
      sorted_methods = methods.
        select {|method|
          sr = method.source_range
          lines_with_backtraces[file].any? {|ln| sr.include? ln }
        }.
        sort_by {|method| method.source_location }
      next if sorted_methods.empty?
      [ file, sorted_methods ]
    }.compact]
  end

  def files_from_bindings ; called_methods_by_file.keys end

  def filter_common_filename_elements text, filenames = files_from_bindings
    file_translation = Hash[filenames.zip(common_dir_prefix_removal filenames)]
    file_translation.inject(text) {|t, (f, sf)| t.gsub(f, sf) }
  end

  def code_context
    context = called_methods_by_file.map {|file, methods|
      receiver = nil
      source = methods.
        map {|pry_method|
          suffix = prefix = nil
          method = pry_method.wrapped
          if receiver != method.receiver
            klass = method.receiver.class
            close_if_needed = ['end',''] unless receiver.nil?
            prefix = "#{klass.to_s.downcase} #{method.receiver}"
            receiver = method.receiver
          end
          code = Pry::Code.from_method method
          source = code.with_line_numbers.to_s.rstrip.gsub(/^\s*(\d+):/) {|n| '% 4s' % n.strip }
          [close_if_needed, prefix, source, ''].flatten.compact
        }
      suffix_if_needed = 'end' if receiver
      [file, source.flatten, suffix_if_needed].compact.join("\n")
    }.join("\n\n").gsub(/(\d+:.*end\n)\nend/) {|s| s.gsub("\n\n", "\n") }
    filter_common_filename_elements context
  end

  def strip_ansi txt ; txt.dup.gsub(/\e\[(\d+(;\d+)?)?./,'') end

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
    return file_parts.first.last(2).join('/') if files.length == 1
    shortest = file_parts.map(&:length).min
    common = shortest.times.find {|n| file_parts.map {|parts| parts[n] }.uniq.length != 1 }
    start = common.zero? ? 0 : common - 1
    file_parts.map {|parts| File.join *parts[start .. -1] }
  end

  def problem
    filtered_full_message + "\n" + code_context
  end

  def local_vars_at_exception
    f,l = backtrace_sites.keys.first
    b = bindings_by_file.values.inject(&:+).find {|bf, bl, b| bf == f && bl == l }.last
    eval "local_variables.map {|v| p [:v, v] ; [v, eval(v.to_s)] }", b
  end

  def custom_types_at_exception
    local_vars_at_exception.
      map {|n,v| m = v.is_a?(Module) ? v : v.class }.
      reject {|m| m == NilClass }.
      map {|m|
        output = StringIO.new
        Pry.run_command("$ #{m} -al", show_output: true, output: output)
        output.rewind
        output.read
      }

  end

  def stop_trace ; set_trace_func nil end

  def initialize *a
    p [:E_init_start, self.class, *a]
    super

    return_count = 2  # When to stop tracing

    sites = backtrace_sites
    files = sites.map {|(f,l),b| f }.uniq

    # Start tracing until we see our caller.
    set_trace_func(proc do |event, file, line, id, binding, kls|
      p [:E_init, :tf, [:e, event, :f, "#{file}:#{line}", :k, kls.inspect[0...40], :i, id, :b, !!binding]] if binding && files.include?(file)

      if binding && files.include?(file)
        # p [:E_init, :tf, :match, :b, binding] # if binding
        bindings_by_file[[kls, id, line]] << [file, line, binding]
        # stop_trace if binding
      end

      if event == :return
        p [:E_init, :tf, :quit_check, :return_count_remaining, return_count]
        stop_trace if (return_count -= 1) <= 0
      end
    end)
    # stop_trace
    p [:E_init, :stf, :done]
  end
end
class StandardError < Exception ; include ExceptionBinding end
class SystemStackError < Exception ; include ExceptionBinding end

