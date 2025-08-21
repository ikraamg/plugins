module Plugins
  class UpcomingMovies < Base
    BASE_URL = 'https://api.themoviedb.org/3'.freeze

    def locals
      { movie:, filter_by_label: }
    end

    def movie
      response = fetch(BASE_URL + lookup_endpoint, headers:)
      random_movie = JSON.parse(response.body)['results'].sample

      {
        title: random_movie['title'], # 'original_title' also available
        overview: random_movie['overview'],
        release_date: random_movie['release_date'], # yyyy-mm-dd
        poster_url: poster_url(random_movie['poster_path'])
      }
    end

    # xhrSelect form
    class << self
      def regions
        Rails.cache.fetch "UPCOMING_MOVIES_REGION", expire_in: 1.year, skip_nil: true do
          response = HTTParty.get(BASE_URL + inst.regions_endpoint, headers: inst.headers)
          data = JSON.parse(response.body)
          data['results'].map { |m| { m['english_name'] => m['iso_3166_1'] } }
        end
      end
    end

    def poster_url(path)
      "https://image.tmdb.org/t/p/w440_and_h660_face#{path}"
    end

    def lookup_endpoint
      "/discover/movie?#{params}"
    end

    def regions_endpoint = '/watch/providers/regions?language=en-US'

    def filter_by = settings['filter_by']

    def filter_by_label = filter_by.gsub('_', ' ').titleize

    # for ease of testing purposes
    def today = Date.today

    def yesterday = Date.yesterday

    def params
      release_date_filter = case filter_by
                            when 'upcoming'
                              "gte=#{today}"
                            when 'now_playing'
                              "lte=#{yesterday}"
                            end

      "include_adult=false&include_video=false&language=en-US&page=1&region=#{settings['upcoming_movies_region']}&primary_release_date.#{release_date_filter}"
    end

    def headers
      {
        'content-type' => 'application/json',
        'authorization' => "Bearer #{Rails.application.credentials.plugins.upcoming_movies.access_token}"
      }
    end
  end
end
