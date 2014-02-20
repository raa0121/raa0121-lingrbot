require 'mechanize'
require 'json'

$agent = Mechanize.new

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    if /^https?:\/\/.*/ =~ m
      if /.(jpg|png|gif)$/ =~ m
        return ""
      end
      begin
        $agent.get(m)
        $agent.page.at('title').inner_text
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
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
