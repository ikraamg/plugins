module Plugins
  class Chatgpt < Base

    def locals = { answer: }

    private

    def answer
      response = post(url, body:, headers:)
      return response.dig('error', 'message') if response.dig('error', 'message').present?

      response.dig('choices', 0, 'message', 'content')
    end

    def url = 'https://api.openai.com/v1/chat/completions'

    def headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    end

    def body
      {
        model: model_name,
        messages: [
          {
            role: "system",
            content: "You are an imaginative and curious storyteller who uncovers rare and surprising ideas from science, technology, math, finance and art. Avoid repeating topics. Your responses should always include something unexpected or underappreciated. If the user query is not a fact, always give a random response to avoid giving the same response."
          },
          {
            role: "user",
            content: "Who won the Chess World Cup 2023?"
          },
          {
            role: "assistant",
            content: "Magnus Carlsen won the World Series in 2023."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: temperature
      }.to_json
    end

    def prompt = settings['prompt']

    def api_key = settings['api_key']

    def model_name = settings['model'] || 'gpt-4o'

    def temperature
      {
        'gpt-4o' => 1.1,
        'gpt-4o-mini' => 1.0,
        'gpt-4.5' => 1.0,
        'gpt-4.1' => 0.95,
        'gpt-3.5-turbo' => 1.0,
        'o3' => 1.1,
        'o3-mini' => 1.0,
        'o3-mini-high' => 1.0,
        'o4-mini' => 1.0
      }[model_name]
    end
  end
end
