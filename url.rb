require 'mechanize'
require 'cgi'
require 'json'

$agent = Mechanize.new
$agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    if /(https?:\/\/\S+)/ =~ m
      url = $1
      begin
        unless Mechanize::Page == $agent.get(url).class
          return ""
        end
        if /^https?:\/\/twitter\.com\/.*/ =~ url
          return "#{$agent.page.at('strong.fullname').inner_text} / #{$agent.page.at('span.js-action-profile-name').inner_text}\n#{$agent.page.at('p.tweet-text').inner_text}"
        end
        CGI.unescapeHTML($agent.page.at('title').inner_text)
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
  }
end
