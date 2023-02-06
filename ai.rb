module Debugger

  def self.prompt_persona
    <<~PROMPT
    You are a skilled #{RUBY_ENGINE} developer acting in a senior mentor role.
    PROMPT
  end
  def self.prompt_backtrace
    <<~PROMPT
    A BACKTRACE_ENTRY is formatted as follows:
      FILENAME:LINENUMBER:in `METHODNAME'
    PROMPT
  end

  def self.prompt_exception
    prompt_backtrace + "\n" +
    <<~PROMPT
    An EXCEPTION is formatted as follows
      BACKTRACE_ENTRY_1: MESSAGE (TYPE)
        FAILING_CODE
          BACKTRACE_ENTRY_1
          BACKTRACE_ENTRY_2
          BACKTRACE_ENTRY_N
    PROMPT
  end

  def self.prompt_parse_exception
    <<~PROMPT
    Parse the following EXCEPTION and fix the error in the code:
    PROMPT
  end

  def self.prompt_snippet
    <<~PROMPT
    A code SNIPPET is formatted as follows
    LINE_NO_1: def METHOD_NAME optional(parameter definition)
    LINE_NO_2:  LINE_OF_CODE
    LINE_NO_N: end
    PROMPT
  end

  def self.prompt_classname_block
    <<~PROMPT
    Snippets with the same CLASSNAME are grouped together in a CLASSNAME_BLOCK.
    The optional parts are left out if blank.
    A TYPE is either 'class' or 'module'
    A CLASSNAME is one or more NAMES separated by ::
    A CLASSNAME_BLOCK is formatted as follows:
    optional(TYPE CLASSNAME)
    SNIPPET_1
    SNIPPET_N
    optional(end)
    PROMPT
  end

  def self.prompt_relevant_code
    <<~PROMPT
    RELEVANT_CODE is formatted as follows
    FILENAME_1
    CLASSNAME_BLOCK_1
    CLASSNAME_BLOCK_2
    CLASSNAME_BLOCK_N
    FILENAME_N
    CLASSNAME_BLOCK_1
    CLASSNAME_BLOCK_2
    CLASSNAME_BLOCK_N
    PROMPT
  end

  def self.prompt_parse_code
    <<~PROMPT
    Parse the following SNIPPET:
    PROMPT
  end

  def self.ai_question e
    msg = [ prompt_persona,
            prompt_snippet,
            prompt_parse_code,
            e.code_context, # .lines[0...9].join,
            prompt_exception,
            prompt_parse_exception,
            e.filtered_full_message,
    ].join("\n")
  end

  def self.ask e
    ai_question e
  end
end
