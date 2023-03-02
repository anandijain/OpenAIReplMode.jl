module OpenAIReplMode

using ReplMaker, HTTP, Markdown, JSON3

MEMORY_SIZE = 5
# todo write this to file
OPENAI_CHAT_HIST = []
headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $(ENV["OPENAI_API_KEY"])"]

"maybe add option to prefix all chats with a prompt (ie julia mode)"
function chat(s)
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
    resp_msg = j.choices[1].message
    c = resp_msg.content
    display(Markdown.parse(c))
end

function __init__()
    initrepl(chat,
        show_function=chat_show,
        prompt_text="chatgpt> ",
        prompt_color=:magenta,
        start_key=')',
        mode_name="chatgpt_mode")
end

end # module OpenAIReplMode
