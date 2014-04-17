require 'mechanize'
require 'cgi'
require 'json'
require 'uri'

$agent = Mechanize.new
$agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  titles = []
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    unless [] == urls = URI.extract(m, ["http", "https"])
      urls.each do |url|
        return "" if url.end_with? '://'
        begin
          unless Mechanize::Page == $agent.get(url).class
            return ""
          end
          if %r`\Ahttps?://(www\.)?twitter.com/[^/]+/status/(\d+)` =~ url
            tweet = $agent.page.at("[data-tweet-id='#{$2}']")
            titles << 'Something wrong with twitter url.' unless tweet
            titles << "#{tweet.at('strong.fullname').inner_text} / #{tweet.at('span.js-action-profile-name').inner_text}\n#{tweet.at('p.tweet-text').inner_text}"
          else
            unless nil == $agent.page.at('title')
              titles << CGI.unescapeHTML($agent.page.at('title').inner_text)
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
      return titles.join("\n")
    end
  }
end
