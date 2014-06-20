require 'mechanize'
require 'cgi'
require 'json'
require 'uri'

$agent = Mechanize.new
$agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  response_lines = []
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    unless [] == urls = URI.extract(m, ["http", "https"]).reject{|url| url.end_with? '://' }
      urls.each do |url|
        begin
          case $agent.get(url)
          when Mechanize::Page, Mechanize::XmlFile
            case url
            when %r`\Ahttp://gyazo\.com/(\w+)`
              gyazo_raw_url = "http://i.gyazo.com/#{$1}.png"
              response_lines << gyazo_raw_url
            when %r`\Ahttps?://(www\.)?twitter.com/[^/]+/(?:status|statuses)/(\d+)`
              $agent.user_agent = "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:30.0) Gecko/20100101 Firefox/30.0"
              $agent.get(url)
              tweet = $agent.page.at("[data-tweet-id='#{$2}']")
              response_lines << 'Something wrong with twitter url.' unless tweet
              response_lines << "#{tweet.at('strong.fullname').inner_text} / #{tweet.at('span.js-action-profile-name').inner_text}\n#{tweet.at('p.tweet-text').inner_text}"
            else
              $agent.user_agent = ""
              if $agent.page.at('title')
                response_lines << CGI.unescapeHTML($agent.page.at('title').inner_text)
              elsif $agent.page.at('h1')
                response_lines << CGI.unescapeHTML($agent.page.at('h1').inner_text)
              elsif $agent.page.at('GUIDE')['title']
                response_lines << CGI.unescapeHTML($agent.page.at('GUIDE')['title'])
              end
            end
          else
            return ""
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
      if [] == response_lines
        return ""
      end
      return response_lines.join("\n")
    end
  }
end
