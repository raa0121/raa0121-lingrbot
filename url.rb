require 'mechanize'
require 'json'

$agent = Mechanize.new

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    if /^https?:\/\/.*[\.jpg]/ =~ m
      begin
        $agent.get(m)
        $agent.page.at('title').inner_text
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          ""
        when '503'
          ""
        when '500'
          ""
        end
      end
    end
  }
end
