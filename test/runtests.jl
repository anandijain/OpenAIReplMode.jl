using OpenAI, ReplMaker
using CSV, DataFrames, JSON3, JSONTables
using HTTP, Markdown

r = list_models(ENV["OPENAI_API_KEY"])
df = DataFrame(r.response.data)

model_name = "gpt-3.5-turbo"
r = retrieve_model(ENV["OPENAI_API_KEY"], model_name)
model_name = "gpt-3.5-turbo-0301"
r = retrieve_model(ENV["OPENAI_API_KEY"], model_name)

# we also want to push chat responses 
MEMORY_SIZE = 5
OPENAI_CHAT_HIST = []
const headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $(ENV["OPENAI_API_KEY"])"];

s = test_msg = "how do i publish a julia package?"

"maybe add option to prefix all chats with a prompt (ie julia mode)"
function chat(s)
    msg = """{"role": "user", "content": "$s"}"""
    msgj = JSON3.read(msg)
    push!(OPENAI_CHAT_HIST, msgj)

    idx1 = max(1, length(OPENAI_CHAT_HIST) - MEMORY_SIZE)
    msgs = OPENAI_CHAT_HIST[idx1:end]
    body = JSON3.write(Dict("model" => "gpt-3.5-turbo", "messages" => msgs))

    resp = HTTP.post("https://api.openai.com/v1/chat/completions"; body, headers)
    j = JSON3.read(resp.body)
    resp_msg = j.choices[1].message
    push!(OPENAI_CHAT_HIST, resp_msg)
    # show(stdout, resp_msg.content)
    c= resp_msg.content
    display(Markdown.parse(c))
    nothing
end


