class Proxy
  def _dup
    d = _orig_dup
    @log = @log.dup
    d
  end
  def _class ; _orig_class end

  def _log ; @log end
  def _wrapped ; @obj end

  def _print_log
    _log.
      map {|msg|
        call = msg[:call]
        args    = call[:args].map {|a| a.inspect[0...40] }.join(', ') if call.include? :args
        result  = call[:result].inspect[0...40]                       if call.include? :result
        puts  "#{call[:method]}" +
              "#{"(#{args if args})"}" +
              "#{" => #{result if result}"}"
      }
    true
  end

  class << self
    private
    def safe_methods ; [:method_missing, :object_id] end
    def undef_methods
      instance_methods.each {|im|
        next if safe_methods.include?(im)
        next if im =~ /^_/
        orig_name = "_orig_#{im}"
        if !instance_methods.include?(orig_name)
          if im !~ /[<>]|==|===|!~|!=/
            # p [:alias_method, orig_name, im]
            eval "alias _orig_#{im} #{im}"
          end
        end
        # p [:undef_method, im]
        undef_method im
      }
    end
  end

  undef_methods

  def method_missing m, *a
    raise ArgumentError, "Method name begins with underscore, should not be here!" if m =~ /^_/
    # p [:mm, m, a]
    r = :call_did_not_succeed
    msg = {}
    call = {method: m}
    call[:args] = a unless a.empty?
    msg[:call] = call
    msg[:caller] = caller
    r = @obj.send(m,*a)
    call[:result] = r
  rescue StandardError => e
    r = e.inspect
  ensure
    @log << msg
    r
  end

  def initialize obj
    @obj = obj
    @log = []
  end
end

# Using the proxy to diagnose why long output doesn't get stored.
#
# cmd = '$ String' ; oi = StringIO.new ; o = Proxy.new oi ; Pry.run_command(cmd, show_output: true, output: o) ; o.rewind ; t = o.read ; t.length
# ios ||= [] ; ios << [$pager_type, cmd, o._log.dup, (t.length if t && t.respond_to?(:length))]
# ios.map {|mp,cm,lg,ln| $l = lg ; [mp, cm, ln, lg.map {|h| h[:call] }] }
#  [:sys,                                                      [:sys,
#   "$ String",                                                  "$ String -a",
#   1038,                                                        0, # should be 6000+
#   [{:method=>:class, :result=>StringIO},                       [{:method=>:class, :result=>StringIO},
#    {:method=>:class, :result=>StringIO},                        {:method=>:class, :result=>StringIO},
#    {:method=>:respond_to?, :args=>[:tty?], :result=>true},      {:method=>:respond_to?, :args=>[:tty?], :result=>true},
#    {:method=>:tty?, :result=>false},                            {:method=>:tty?, :result=>false},
#    {:method=>:respond_to?, :args=>[:tty?], :result=>true},      {:method=>:respond_to?, :args=>[:tty?], :result=>true},
#    {:method=>:tty?, :result=>false},                            {:method=>:tty?, :result=>false},
#    {:method=>:print, :args=> ["..."], :result=>nil},         	  # missing call to print
#    {:method=>:inspect, :result=>"#<StringIO>"},                 {:method=>:inspect, :result=>"#<StringIO>"},

