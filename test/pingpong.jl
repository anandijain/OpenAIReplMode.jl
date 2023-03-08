using ReplMaker, HTTP, Markdown, JSON3
using OpenAIReplMode

macro redirect(ex)
    # temp = tempname() * ".txt"
    :(
        io = IOBuffer()
        open($temp, "w") do fileio
            redirect_stdout(fileio) do
                $ex
            end
        end
    )
end
function capture_stdout(expr)
    io = IOBuffer()
    old_out = Base.stdout
    redirect_stdout(io)
    try
        eval(expr)
    finally
        redirect_stdout(old_out)
    end
    return String(take!(io))
end

stream = Base.BufferStream()
stream = IOStream()
open(stream, "w") do io
    write(io, "hello")
end

function appendc(j)
    code_str = to_code_str(j)
    open(@__FILE__, "a") do f
        write(f, "\n\n" * code_str)
    end
end
appendc() = appendc(ans)

macro tc(ex)
    :(
        try
            $ex
        catch e
            e
        end
    )
end

macro tce(ex)
    :(
        try
            $ex
        catch e
            e, current_exceptions()
        end
    )
end

codeblocks() = codeblocks(ans)

# write a julia function that uses Dates.jl to compute the number of nanoseconds between two DateTime
PROMPT = """
everything below this line is template of what I want you to return, except you need to replace "..." with the actual test code you want to run. make sure to keep the @mytestset macro call before the actual testset:

```julia 

```

```julia
e = @tce @testset ...
```
"""

resp = chat(PROMPT)
ch = getc(resp)
bs = codeblocks(ch)
code_str = join(bs, '\n')
chat_show(resp)

io = IOBuffer()
Base.show_exception_stack(io, es)
estr = String(take!(io))
erj = chat(estr)

# showerror(stdout, exc)

# Make sure that the TESTSET CODE BLOCK is an `@testset` block
# I want to wrap the second code block with `redirect_stdio(stdout="stdout.txt", stderr="stderr.txt") do @testset ... end` so that I can see the exceptions that are thrown. 
preprompt = 
"""
Solve the below task and return exactly two code blocks.
The first is the function that solves the task, and the second which is code that tests the function with `@testset`. 
I also want all `using PACKAGE` statements to go in the first code block and do not put any `using PACKAGE` statements in the second code block.
This should include `using Test`, which should still go in the first code block. Don't make the testset const.

"""
prompt = "Task: Please write a function called reverse_string that takes a string as input and returns a new string with the characters reversed."
full_prompt = preprompt * prompt
resp = replchat(full_prompt)
h = OpenAIReplMode.OPENAI_CHAT_HIST[end].content
bs = codeblocks(h)
cs = to_code_str(resp)
cs = to_code_str(h)
chat_show(resp)
est = try
    eval(Meta.parseall(cs))
catch e
    e#, current_exceptions()
end

resp_preprompt = """
$full_prompt

Below is the result of running the tests. If there are any errors, please fix them and try again. If there are no errors, then you are done! 

$(repr(est.errors_and_fails))
"""
resp2 = chat(resp_preprompt)
ds = Docs.doc.([MethodError, ArgumentError])
clues = join(ds, "\n")
resp3 = chat("The definitions of the error types might help you fix the testset, $clues")
cs = to_code_str(resp3)

chs = []

est = try
    eval(Meta.parseall(cs))
catch e
    e#, current_exceptions()
end

p2 = """
Write a Julia function called count_uppercase_letters that takes in a string as an argument and returns the number of uppercase letters in that string.

Here's an example of the expected behavior of the function:

julia> count_uppercase_letters("Happiness Is A Warm Gun")
8


Write a test block that includes at least three test cases for the count_uppercase_letters function using the @test macro. The test block
should include a test case that checks if the function returns 0 when an empty string is passed as an argument, and another test case that
checks if the function correctly handles mixed-case input. The test cases should cover all relevant scenarios, and the test block should be
named "count_uppercase_letters".

"""
# this kind of thing could be dangerous, we probably don't want to eval AI code automatically. 
# but IDGAF!!!! i is cool and gangstar
est = try
    eval(Meta.parseall(to_code_str(chat(p2))))
catch e
    e#, current_exceptions()
end

est2 = try
    eval(Meta.parseall(to_code_str(chat(p2 * "\n\n" * repr(est.errors_and_fails)))))
catch e
    e#, current_exceptions()
end

# chat("""
# clue: 
# julia> apropos(r"isupper")
# Base.Unicode.islowercase
# Base.Unicode.isuppercase
# Base.Unicode.iscased
# """
# )
h = OpenAIReplMode.OPENAI_CHAT_HIST[end].content
est3 = try
    eval(Meta.parseall(to_code_str(h)))
catch e
    e#, current_exceptions()
end
est4 = try
    ch = chat(p2 * "\n\n" * repr(est3.errors_and_fails))
    eval(Meta.parseall(to_code_str(ch)))
catch e
    e#, current_exceptions()
end
