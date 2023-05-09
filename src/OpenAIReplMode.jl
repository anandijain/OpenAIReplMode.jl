module OpenAIReplMode

using ReplMaker, HTTP, Markdown, JSON3
using REPL
using OpenAI

# https://github.com/JuliaLang/julia/issues/25750
# this would have made life easy
# Base.getproperty(d::Dict{K,V}, v::V) where {K, V} = d[v]

function make_message(s)
    msg = Dict("role" => "user", "content" => s)
    msgj = JSON3.read(JSON3.write(msg))
    push!(OPENAI_CHAT_HIST, msgj)
    msgj
end

function build_messages(s)
    idx1 = max(1, length(OPENAI_CHAT_HIST) - MEMORY_SIZE)
    msgs = OPENAI_CHAT_HIST[idx1:end]
    Dict("model" => OPENAI_GPT_MODEL, "messages" => msgs)
end

"maybe add option to prefix all chats with a prompt (ie julia mode)
add option to not use history or specify history size from callsite
maybe use preferences too?
"
function chat(s)
    msgj = make_message(s)
    body = JSON3.write(build_messages(s))
    try
        resp = HTTP.post("https://api.openai.com/v1/chat/completions"; body, headers)
        j = JSON3.read(resp.body)
        open(HIST_FILE, "a") do io
            JSON3.write(io, [msgj, j])
        end
        resp_msg = j.choices[1].message
        push!(OPENAI_CHAT_HIST, resp_msg)
        j
    catch e
        if e isa InterruptException
            @info typeof(e)
        else
            rethrow(e)
        end
    end

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

function codeblocks(markdown::AbstractString; prefix="```")
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

codeblocks(j; prefix="```") = codeblocks(getc(j); prefix)
function codeblocks(; prefix="```")
    assistant_messages = filter(m -> m["role"] == "assistant", OPENAI_CHAT_HIST)
    last_message = isempty(assistant_messages) ? "" : assistant_messages[end]["content"]
    extract_code_blocks(last_message)
end

function extract_code_blocks(markdown::String)
    code_blocks = []
    inside_code_block = false
    current_block = ""

    for line in split(markdown, '\n')
        if startswith(line, "```") && inside_code_block
            push!(code_blocks, current_block)
            current_block = ""
            inside_code_block = false
        elseif inside_code_block
            current_block = current_block * line * "\n"
        elseif startswith(line, "```")
            inside_code_block = true
        end
    end

    return code_blocks
end

getc(x) = x.choices[1].message.content

function to_code_str(j; kws...)
    to_code_str(getc(j); kws...)
end

function to_code_str(c::AbstractString; kws...)
    bs = codeblocks(c; kws...)
    join(bs, '\n')
end

chat_reset!() = begin
    global OPENAI_CHAT_HIST = []
end

set_model!(m) = begin
    global OPENAI_GPT_MODEL = m
end

# stream stuff. todo have it log 
function unzip(d::Dict)
    xs = collect(d)
    first.(xs), last.(xs)
end
unzip(xs) = (first.(xs), last.(xs))

function goodbad(f, xs; verbose=false)
    n = length(xs)

    good = []
    bad = []
    for (i, x) in enumerate(xs)
        verbose && @info x
        try
            y = f(x)
            push!(good, (i, x) => y)
        catch e
            push!(bad, (i, x) => e)
        end
    end
    good, bad
end

function fix_msg_for_streamcb(msg)
    ks, vs = unzip(collect(msg))
    Dict(String.(ks) .=> vs)
end

function stream_chat(s)
    msgj = make_message(s)
    idx1 = max(1, length(OPENAI_CHAT_HIST) - MEMORY_SIZE)
    msgs = OPENAI_CHAT_HIST[idx1:end]
    msgs = fix_msg_for_streamcb.(msgs)
    try
        global STREAM_BUF = []
        c = OpenAI.create_chat(
            OPENAI_API_KEY,
            OPENAI_GPT_MODEL,
            msgs; streamcallback=show_stream_content
        )
        resp_str = stream_resp_to_msg(c)
        push!(OPENAI_CHAT_HIST, JSON3.read(JSON3.write(Dict(["role" => "assistant", "content" => resp_str]))))
        resp_str

    catch e
        if e isa InterruptException
        elseif e isa HTTP.Exceptions.RequestError
            if e.error isa InterruptException
                push!(OPENAI_CHAT_HIST, JSON3.read(JSON3.write(Dict(["role" => "assistant", "content" => join(STREAM_BUF)]))))
                @info typeof(e.error)
            end
        else
            rethrow(e)
        end
    end
end

# repl_stream_chat = stream_resp_to_msg ∘ stream_chat
repl_stream_chat(s) = begin
    r = stream_chat(s)
    s = stream_resp_to_msg(r)
    chat_show(s)
    s
end

function stream_chat_show(io, M, s)
    display(Markdown.parse(s))
end

getdc(x) = x.choices[1].delta.content
function stream_resp_to_msg(resp;say=true)
    rs = resp.response
    gs, _ = goodbad(getdc, rs)
    s = join(last.(gs))
    # say && run(`say '$s'`)
    s
end

function show_stream_content(response)
    segments = split(response, "\n")
    for segment in segments
        json_str = match(r"(?<=data: ).*", segment)
        if !isnothing(json_str)
            try
                json_response = JSON3.read(json_str.match)
                choices = get(json_response, "choices", [])
                for choice in choices
                    delta = get(choice, "delta", nothing)
                    if delta !== nothing

                        content = get(delta, "content", nothing)
                        if content !== nothing
                            push!(STREAM_BUF, content)
                            # run(`say $content`)
                            print(content)
                        end
                    end
                end
            catch e
                continue
            end

        end
    end
end

function init_repl(; kws...)
    global OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
    global HIST_FILE = joinpath(dirname(REPL.find_hist_file()), "openai_hist.json")
    global MEMORY_SIZE = 10
    global OPENAI_GPT_MODEL = "gpt-4"
    # global OPENAI_GPT_MODEL = "gpt-3.5-turbo"
    # todo write this to file
    # add being able to switch histories
    global OPENAI_CHAT_HIST = []
    global STREAM_BUF = []
    global OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
    global headers = ["Content-Type" => "application/json", "Authorization" => "Bearer " * OPENAI_API_KEY]

    initrepl(chat,
        show_function=chat_show,
        prompt_text="chatgpt-$OPENAI_GPT_MODEL> ",
        prompt_color=:magenta,
        start_key=')',
        mode_name="chatgpt_mode",
        kws...)

    initrepl(stream_chat,
        show_function=stream_chat_show,
        prompt_text="chatgpt-stream-$OPENAI_GPT_MODEL> ",
        prompt_color=:magenta,
        start_key='`',
        mode_name="chatgpt_stream_mode",
        kws...)

end

# __init__() = isdefined(Base, :active_repl) ? init_repl() : nothing

# apologies for heavy exporting
export chat, getc, chat_show
export replchat, codeblocks, to_code_str, chat_reset!
export stream_chat, repl_stream_chat, getdc#, show_stream_content

end # module OpenAIReplMode
