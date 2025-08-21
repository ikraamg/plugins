module Plugins
  class Reddit < Base
    SUB_REDDIT_LIMIT = 2.0.freeze
    LIMIT = 10.0.freeze

    def locals
      { featured_posts:, sort_by:, truncate_title:, include_metadata: }
    end

    class << self
      def redirect_url
        query = {
          response_type: 'code',
          duration: 'permanent',
          scope: 'read',
          state: SecureRandom.hex,
          client_id: Rails.application.credentials.plugins[:reddit][:client_id],
          redirect_uri: "#{Rails.application.credentials.base_url}/plugin_settings/reddit/redirect"
        }.to_query
        "https://www.reddit.com/api/v1/authorize?#{query}"
      end

      def fetch_access_token(code)
        body = {
          grant_type: 'authorization_code',
          redirect_uri: "#{Rails.application.credentials.base_url}/plugin_settings/reddit/redirect",
          code: code
        }
        auth = {
          username: Rails.application.credentials.plugins[:reddit][:client_id],
          password: Rails.application.credentials.plugins[:reddit][:client_secret]
        }
        response = HTTParty.post("https://www.reddit.com/api/v1/access_token", body:, basic_auth: auth)
        {
          access_token: response.parsed_response['access_token'],
          refresh_token: response.parsed_response['refresh_token']
        }
      end

      def refresh_access_token(refresh_token)
        return unless refresh_token

        body = {
          grant_type: 'refresh_token',
          refresh_token: refresh_token
        }
        auth = {
          username: Rails.application.credentials.plugins[:reddit][:client_id],
          password: Rails.application.credentials.plugins[:reddit][:client_secret]
        }
        response = HTTParty.post("https://www.reddit.com/api/v1/access_token", body:, basic_auth: auth)
        response.parsed_response['access_token']
      end
    end

    private

    def featured_posts
      computed_reddit_posts = subreddits.map do |subreddit|
        posts = Rails.cache.fetch "#{subreddit}-#{sort_by}", expire_in: 30.minutes, skip_nil: true do # Avoid querying same subreddit across different users.
          response = fetch_data(subreddit)

          if response.nil?
            []
          else
            posts = response.dig('data', 'children')
            if posts.nil?
              []
            else
              # ignore mod/admin-pinned posts since they often don't change
              non_pinned_posts = posts.reject { |p| p.dig('data', 'stickied') }

              non_pinned_posts.map do |post|
                {
                  title: post.dig('data', 'title'),
                  author: post.dig('data', 'author'),
                  votes: post.dig('data', 'ups')
                }
              end
            end
          end
        end

        {
          subreddit: subreddit,
          posts: posts
        }
      end

      raise DataFetchError if computed_reddit_posts.map { |m| m[:posts] }.flatten.compact.count.zero?

      computed_reddit_posts
    end

    def fetch_data(subreddit)
      retry_count = 0
      begin
        return {} if retry_count >= 2 # retry just once, because fetch does retry internally.

        response = fetch(url(subreddit), headers:)
        raise AccessTokenExpired if response.code == 403
        raise UnauthorizedError if response.code == 401

        response
      rescue AccessTokenExpired, UnauthorizedError
        retry_count += 1
        raise DataFetchError if refresh_token.nil?

        new_access_token = Plugins::Reddit.refresh_access_token(refresh_token)
        credentials = plugin_settings.encrypted_settings
        credentials['reddit']['access_token'] = new_access_token
        plugin_settings.update(encrypted_settings: credentials)
        self.settings["reddit"]['access_token'] = new_access_token
        sleep retry_count
        retry
      end
    end

    def subreddits
      string_to_array(settings['subreddits'], limit: SUB_REDDIT_LIMIT)
    end

    def url(subreddit)
      "https://oauth.reddit.com/r/#{subreddit}/#{sort_by}/.json?limit=#{limit}&sort=#{sort_by}&t=#{time_period}"
    end

    # hot, new, top
    def sort_by
      settings['sort_by']
    end

    def time_period
      return 'day' unless settings['time_period'] # optional field, default value

      settings['time_period']
    end

    def truncate_title
      return true unless settings['truncate_title'] # optional field, default value

      settings['truncate_title'] == 'yes'
    end

    def include_metadata
      return true unless settings['include_metadata'] # optional field, default value

      settings['include_metadata'] == 'yes'
    end

    # screen fits ~12-14 max, divide by subreddits provided
    def limit = (LIMIT / subreddits.count).floor

    def access_token = settings.dig('reddit', 'access_token')

    def refresh_token = settings.dig('reddit', 'refresh_token')

    def headers
      {
        'content-type' => 'application/json',
        'authorization' => "Bearer #{access_token}"
      }
    end
  end
end
