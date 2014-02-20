require 'mechanize'

@agent = Mechanize.new

post '/url' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    if /^https?:\/\/.*/ =~ m
      @agent.get(m)
      @agent.page.at('title').inner_text
    end
  }
end
