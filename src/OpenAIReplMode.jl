module OpenAIReplMode

using ReplMaker, HTTP, Markdown, JSON3

"maybe add option to prefix all chats with a prompt (ie julia mode)"
function chat(s)
    # @info s, typeof(s)
    # @info esc(s)

    msg = Dict("role" => "user", "content" => s)
    msgj = JSON3.read(JSON3.write(msg))
    push!(OPENAI_CHAT_HIST, msgj)

    idx1 = max(1, length(OPENAI_CHAT_HIST) - MEMORY_SIZE)
    msgs = OPENAI_CHAT_HIST[idx1:end]
    body = JSON3.write(Dict("model" => "gpt-3.5-turbo", "messages" => msgs))

    resp = HTTP.post("https://api.openai.com/v1/chat/completions"; body, headers)
    j = JSON3.read(resp.body)
    resp_msg = j.choices[1].message
    push!(OPENAI_CHAT_HIST, resp_msg)
    j
end

"todo fix this up a bit"
function chat_show(io, M, j)
    display(Markdown.parse(getc(j)))
end

function chat_show(j)
    display(Markdown.parse(getc(j)))
end

function chat_show(s::AbstractString)
    display(Markdown.parse(s))
end

replchat(s) = begin
    j = chat(s)
    chat_show(j)
    j
end

function codeblocks(markdown::AbstractString; prefix="```julia")
    blocks = Vector{String}()
    mdlines = split(markdown, "\n")
    in_block = false
    curr_block = ""
    for line in mdlines
        if startswith(line, prefix)
            in_block = true
            curr_block = ""
        elseif startswith(line, "```")
            in_block = false
            push!(blocks, curr_block)
        end
        if in_block && !startswith(line, prefix)
            curr_block *= line * "\n"
        end
    end
    return blocks
end

getc(x) = x.choices[1].message.content

function to_code_str(j)
    to_code_str(getc(j))
end

function to_code_str(c::AbstractString)
    bs = codeblocks(c)
    join(bs, '\n')
end

function __init__()
    global MEMORY_SIZE = 10
    # todo write this to file
    global OPENAI_CHAT_HIST = []
    global headers = ["Content-Type" => "application/json", "Authorization" => "Bearer " * ENV["OPENAI_API_KEY"]]

    initrepl(chat,
        show_function=chat_show,
        prompt_text="chatgpt> ",
        prompt_color=:magenta,
        start_key=')',
        mode_name="chatgpt_mode")
end

export chat, getc, chat_show
export replchat, codeblocks, to_code_str

# __init__() = isdefined(Base, :active_repl) ? init_repl() : nothing

end # module OpenAIReplMode
