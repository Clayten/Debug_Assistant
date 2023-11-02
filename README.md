# Ruby Exception Debugger and AI Coding Assistant

## About

Takes an exception and creates a debugging question for an AI coding assistant.

Includes code snippets and local variables from local stack frames to the the assistant enough context to solve the problem and provide a fix.

Generally it takes as long to ask a useful question as to solve the problem yourself. This project automates the gathering of relevant code and variables while staying within a reasonable token limit.

## Prerequisites

Ruby and the pry gem (or irb).

## Usage

Encounter an error and ask an AI assistant to fix it.
```ruby
# Call the test routine, saving the exception in a variable
e = Debugger.check

# Create the 'please fix this' message.
msg = Debugger.ask e

# Ask the AI to fix the problem (this code is from the AI repo)
CH::OpenAI.ask(msg, max_tokens: 500, model: 'text-davinci-003')
```

### Question from sample usage

    You are a skilled ruby developer acting in a senior mentor role.
    
    Read the following code and prepare to answer question about it.
    
    Code blocks are listed in the order of the stack trace, backwards.
    A code block consists of a class or module name, then an optional code block and and optional listing of local variables.
    The code is listed with line numbers, with a "rocket" symbol => indicating what line is being executed.
    Local variables are displayed in a list of NAME: VALUE pairs
    
    dev/debug_assistant/test_a.rb
    Module Debugger::A
        19: def self.a_block
        20:   lambda {|x,y|
     => 21:     x + y
        22:   }
        23: end
    end
    Local Variables:
                       x: "cat"
                       y: #<Debugger::Point:0x000000010e4de838 @x=
    --------
    dev/debug_assistant/test_a.rb
    Module Debugger::A
        12: def self.a arg
        13:   blk = a_block
        14:   obj = Point.new 0,1,2
     => 15:   s = blk[arg,obj]
        16:   puts s
        17: end
    end
    Local Variables:
                     arg: "cat"
                     blk: #<Proc:0x000000010e5dc7f8 dev/debug_assi
                     obj: #<Debugger::Point:0x000000010e4de838 @x=
                       s: nil
    --------
    A BACKTRACE_ENTRY is formatted as follows:
      FILENAME:LINENUMBER:in `METHODNAME'
    
    An EXCEPTION is formatted as follows
      BACKTRACE_ENTRY_1: MESSAGE (TYPE)
        FAILING_CODE
          BACKTRACE_ENTRY_2
          BACKTRACE_ENTRY_N
    
    Read the following EXCEPTION and fix the error in the code:
    
    dev/debug_assistant/test_a.rb:21:in `+': no implicit conversion of Debugger::Point into String (TypeError)
            x + y
            from dev/debug_assistant/test_a.rb:21:in `block in a_block'
            from dev/debug_assistant/test_a.rb:15:in `a'
            from dev/debug_assistant/test_b.rb:8:in `b2'
            from dev/debug_assistant/test_b.rb:4:in `b'
            from dev/debug_assistant/test_c.rb:6:in `c'
            from dev/debug_assistant/debug_assistant.rb:15:in `c'
            from dev/debug_assistant/debug_assistant.rb:21:in `check'

### Response to question

    The error is that there is an implicit conversion of Debugger::Point into a String, which is not allowed. To fix the error, the code in line 21 should be changed to use a method that can convert the Debugger::Point object to a String, such as the .to_s method. The updated code would look like this:
    
    19: def self.a_block
    20:   lambda {|x,y|
    21:     x + y.to_s
    22:   }
    23: end

## Other files

### Sample code files

These files contain a subtle error we're trying to debug. Shows how the library functions across files.

### Proxy library

A development tool, used to trace calls and responses to an object.

## License

AGPLv2
