require 'json'
require 'open-uri'
require 'cgi'

get "/nicodic" do
  "lingr bot id:nicodic"
end

post "/nicodic" do
  content_type :text
  json = JSON.parse(request.body.string)
  json["events"].select {|e| e["message"]}.map {|e|
    m = e["message"]["text"]
    case m 
    when /nicodic:(.*)/
      "#{JSON.parse(open("http://api.nicodic.jp/page.summary/_/a/#{CGI.escape($1)}").read.sub(/^_\(/,"").sub(/\);$/,""))["summary"]}"
    end
  }
end
