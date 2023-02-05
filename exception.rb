# Capture the variables from the site of an exception and display relevant info
#
# https://stackoverflow.com/questions/7647103/can-i-access-the-binding-at-the-moment-of-an-exception-in-ruby
# https://stackoverflow.com/questions/106920/how-can-i-get-source-and-variable-values-in-ruby-tracebacks
#

module ExceptionBinding
  def filtered_files
    %w[\.rubies \.gem (pry)] + [__FILE__.gsub('/','\/')]
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
    backtrace || caller[2..-1]
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
      bts[[file, line]] = method
    }
    bts
  end

  def lvs bind
    eval "local_variables.map {|v| [v, eval(v.to_s)] }", bind
  end

  def bindings ; @bindings ||= Hash.new {|h,k| h[k] = [] } end

  def methods
    bs = bindings.values.inject(&:+).map(&:last)
    ms = Hash[bs.map {|b| m = Pry::Method.from_binding b ; [m.source_location, m]}].values
  end

  def methods_by_file
    methods.inject(Hash.new {|h,k| h[k] = [] }) {|h,m| h[m.source_file] << m ; h }
  end

  def context
    methods_by_file.map {|file, methods|
      receiver = nil
      source = methods.
        sort_by {|method| method.source_location }.
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
          $s = source = code.with_line_numbers.to_s
          [close_if_needed, prefix, source.rstrip].flatten.compact
        }
      suffix_if_needed = 'end' if receiver
      [file, source.flatten, suffix_if_needed].compact.join("\n")
    }.join("\n\n")
    # $c = cs = ms.map {|m| Pry::Code.from_method m }
  end

  def filtered_full_message
    msg = full_message.
      lines.
      reject {|l| l =~ file_filter }.
      reject {|l| l.strip.empty? }
    no_ansi = msg.join.gsub(/\e\[\d+(;\d+)?./,'')
  end

  def common_dir_prefix_removal files
    file_parts = files.map {|file| file.split('/').reject(&:empty?) }
    shortest = file_parts.map(&:length).min
    common = shortest.times.find {|n| file_parts.map {|parts| parts[n] }.uniq.length != 1 }
    file_parts.map {|parts| File.join *parts[common - 1 .. -1] }
  end

  def problem
    filtered_full_message + "\n" + context
  end

  def filtered_problem
    shortened_filenames = common_dir_prefix_removal methods_by_file.keys
    file_translation = Hash[methods_by_file.keys.zip(shortened_filenames)]
    file_translation.inject(problem) {|pr, (f, sf)| pr.gsub(f, sf) }
  end

  def call_sites
    Hash[bindings.map {|k,a| [k,a.sort_by {|_,l,_| l }.first] }]
  end

  def initialize *a
    # p [:E_init_start, self.class, *a]
    super *a

    $c = filtered_caller

    return_count = 2  # When to stop tracing

    $s = sites = backtrace_sites
    $f = files = sites.map {|(f,l),b| f }.uniq

    # Start tracing until we see our caller.
    set_trace_func(proc do |event, file, line, id, binding, kls|
      # p [:E_init, :tf, [:e, event, :f, "#{file}:#{line}", :k, kls.inspect[0...40], :i, id, :b, !!binding]] if binding && files.include?(file)

      if binding && files.include?(file)
        # p [:E_init, :tf, :match, :b, binding] # if binding
        bindings[[kls, id]] << [file, line, binding]
        # set_trace_func(nil) if binding
      end

      if event == :return
        p [:E_init, :tf, :quit_check, :return_count_remaining, return_count]
        set_trace_func(nil) if (return_count -= 1) <= 0
      end
    end)
    # set_trace_func(nil)
    # p [:E_init, :stf, :done]
  end
end
class StandardError < Exception ; include ExceptionBinding end
class SystemStackError < Exception ; include ExceptionBinding end

