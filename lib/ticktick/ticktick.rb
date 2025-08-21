module Plugins
  class Ticktick < Base
    def locals
      { tasks: }
    end

    class << self
      def redirect_url
        query = {
          client_id: Rails.application.credentials.plugins[:ticktick][:client_id],
          scope: 'tasks:read',
          response_type: 'code',
          redirect_uri: "#{Rails.application.credentials.base_url}/plugin_settings/ticktick/redirect"
        }.to_query
        "https://ticktick.com/oauth/authorize?#{query}"
      end

      def fetch_access_token(code)
        body = {
          grant_type: "authorization_code",
          client_id: Rails.application.credentials.plugins[:ticktick][:client_id],
          client_secret: Rails.application.credentials.plugins[:ticktick][:client_secret],
          redirect_uri: "#{Rails.application.credentials.base_url}/plugin_settings/ticktick/redirect",
          scope: 'tasks:read',
          code: code
        }
        response = HTTParty.post("https://ticktick.com/oauth/token", body: URI.encode_www_form(body), headers: { "Content-Type" => "application/x-www-form-urlencoded" })
        response['access_token']
      end

      def projects(access_token)
        response = HTTParty.get('https://ticktick.com/open/v1/project', headers: headers(access_token))
        response.parsed_response.map { |m| { m['name'] => m['id'] } }&.push({ 'Inbox' => 'inbox' })
      end

      def headers(access_token)
        {
          "Authorization" => "Bearer #{access_token}",
          "Content-Type" => "application/json"
        }
      end
    end

    private

    def task_url(project_id)
      "https://ticktick.com/open/v1/project/#{project_id}/data"
    end

    def tasks
      response = HTTParty.get(task_url(project_id), headers: Plugins::Ticktick.headers(access_token))
      response['tasks']
        .sort_by { |it| Date.parse(it['dueDate'] || (Date.today + 100.days).to_s) }
        .map do |it|
          {
            content: it['title'],
            due: due_date(it)
          }
        end
    end

    def due_date(task)
      return nil unless task['dueDate'].present?

      l(DateTime.parse(task['dueDate']).in_time_zone(task['timeZone']).to_date, format: :short, locale:)
    end

    def project_id = settings['ticktick_project_id']

    def access_token
      settings.dig('ticktick', 'access_token')
    end
  end
end
