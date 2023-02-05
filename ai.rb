module Debugger
  def self.prompt
    <<~PROMPT
    You are a skilled #{RUBY_ENGINE} v#{RUBY_VERSION} developer acting in a senior mentor role.
    A junior programmer encountered an exception developing a program and has included the exception and relevant code snippets.
    A BACKTRACE_ENTRY is formatted as follows:
      FILENAME:LINENUMBER:in `METHODNAME'
    An EXCEPTION is formatted as follows
      BACKTRACE_ENTRY_0: MESSAGE (TYPE)
        FAILING_CODE
          BACKTRACE_ENTRY_0
          BACKTRACE_ENTRY_1
          BACKTRACE_ENTRY_N
    Relevant code is displayed by one or more FILENAMEs with one or more SNIPPETs per filename.
    Lines of each SNIPPET are numbered, matching the BACKTRACE_ENTRIES.
    SNIPPETs are surrounded by their class/module and matching end statement, if applicable.
    SNIPPETS in the same class/module are displayed together.
    PROMPT
  end

  def self.ai_question e
    msg = prompt + "\n" + debug_msg(e)
  end

  def self.ask e
    ai_question e
  end
end
