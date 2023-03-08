using ReplMaker, HTTP, Markdown, JSON3

using OpenAIReplMode, URIs
# resp = OpenAIReplMode.chat("fib in julia")

body = JSON3.write(Dict("date" => today()))
body = Dict("date" => string(today()))
url = URI(URI("https://api.openai.com/v1/usage"), query=body)
resp = HTTP.get(url; headers=OpenAIReplMode.headers);
j = JSON3.read(resp.body)
df = DataFrame(j.data)
a = sum(df.n_context_tokens_total)
b = sum(df.n_generated_tokens_total)
# Model	Usage
# gpt-3.5-turbo	$0.002 / 1K tokens

# cost = (a+b)/1000 * 0.002
# wow i spent 8 cents thats incredible