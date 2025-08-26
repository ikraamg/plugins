module Plugins
  class Unsplash < Base

    def locals
      { image_url: }
    end

    private

    def image_url = fetch(url, query:, headers:)['urls']['regular']

    def url = 'https://api.unsplash.com/photos/random'

    def query = { query: search, orientation: 'landscape' }

    def headers = { "Authorization" => "Client-ID #{access_token}" }

    def search = settings['search']

    def access_token = Rails.application.credentials.plugins[:unsplash][:access_key]
  end
end
