require 'mechanize'
require 'cgi'
require 'json'
require 'uri'

$agent = Mechanize.new

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  response_lines = []
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    unless [] == urls = URI.extract(m, ["http", "https"]).reject{|url| url.end_with? '://' }
      urls.map do |url|
        begin
          unless Mechanize::Page == $agent.get(url).class
            return ""
          end
          if %r`\Ahttps?://(www\.)?twitter.com/[^/]+/status/(\d+)` =~ url
            $agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
            tweet = $agent.page.at("[data-tweet-id='#{$2}']")
            response_lines << 'Something wrong with twitter url.' unless tweet
            response_lines << "#{tweet.at('strong.fullname').inner_text} / #{tweet.at('span.js-action-profile-name').inner_text}\n#{tweet.at('p.tweet-text').inner_text}"
          else
            if $agent.page.at('title')
              response_lines << CGI.unescapeHTML($agent.page.at('title').inner_text)
            elsif $agent.page.at('h1')
              response_lines << CGI.unescapeHTML($agent.page.at('h1').inner_text)
            end
          end
        rescue Mechanize::ResponseCodeError => ex
          case ex.response_code
          when '403'
            return ""
          when '404'
            return ""
          when '503'
            return ""
          when '500'
            return ""
          end
        end
      end
      return response_lines.join("\n")
    end
  }
end
