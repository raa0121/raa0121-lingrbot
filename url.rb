require 'mechanize'
require 'cgi'
require 'json'
require 'uri'

$agent = Mechanize.new
$agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
@agent.request_headers = {
  'Accept-Language' => 'ja,en-US;q=0.8,en;q=0.6'
}

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  response_lines = []
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    unless [] == urls = URI.extract(m, ["http", "https"]).reject{|url| url.end_with? '://' }
      urls.each do |url|
        begin
          $agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
          case $agent.get(url)
          when Mechanize::Page
            case url
            when %r`\Ahttp://gyazo\.com/(\w+)`
              gyazo_hash = $1
              gyazo_ext =
                case Net::HTTP.start('i.gyazo.com', 80) {|http| http.head("/#{gyazo_hash}.png").code }
                when '200' then :png
                else :jpg
                end
              response_lines << "http://i.gyazo.com/#{gyazo_hash}.#{gyazo_ext}"
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
              end
            end
          when Mechanize::XmlFile
            if $agent.page.at('GUIDE')['title'] 
              response_lines << CGI.unescapeHTML($agent.page.at('GUIDE')['title'])
            end
          else
            return ""
          end
          if [] == response_lines
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
