model_name = "gpt-3.5-turbo"
r = retrieve_model(ENV["OPENAI_API_KEY"], model_name)
r = list_models(ENV["OPENAI_API_KEY"])
df = DataFrame(r.response.data)

model_name = "gpt-3.5-turbo-0301"
r = retrieve_model(ENV["OPENAI_API_KEY"], model_name)
