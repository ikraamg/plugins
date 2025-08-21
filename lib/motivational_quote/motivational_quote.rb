module Plugins
  class MotivationalQuote < Base

    def locals
      { quote: }
    end

    private

    def url = "https://zenquotes.io/api/today"

    def quote
      resp = fetch(url)
      { content: resp.dig(0, 'q'), author: resp.dig(0, 'a') }
    end
  end
end
