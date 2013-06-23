#!/usr/bin/ruby
# -*- coding utf-8 -*-
require 'sinatra'
require "mechanize"
require 'rexml/document'

agent = Mechanize.new

get '/nicothumb' do
  content_type :text
  "thumb"
end

post '/nicothumb' do
  content_type :text
  json = JSON.parse(request.body.string)
  json["events"].map{|e|
    if e["message"]
      m = e["message"]["text"]
      if /^http:\/\/(www.)?nico(.ms\/|video.jp\/watch\/)(.*)?.*$/ =~ m
        html = agent.get("http://ext.nicovideo.jp/api/getthumbinfo/#{$3}")
        next unless html
        info = REXML::Document.new html.body
        next unless info.elements['nicovideo_thumb_response']
        "#{info.elements['nicovideo_thumb_response/thumb/thumbnail_url'].text}\#.jpg"
      elsif /^http:\/\/www.pixiv.net\/member_illust.php\?mode=medium&illust_id=\d+/ =~ m
        agent.get(m)
        pixiv = agent.page.at('a.medium-image').children[0].attributes["src"].value
        file = Time.now.to_i
        agent.get(pixiv, nil,
                  "http://www.pixiv.net",
                  nil).save("./pixiv_#{file}.png") 
        url = `./gyazo pixiv_#{file}.png`.gsub("\n","")
        File.delete("pixiv_#{file}.png")
        "#{url.sub("//","//cache.")}.png"
      elsif %r#^http://stat\.ameba\.jp/user_images/.+\.(jpe?g|gif|png)$# =~ m
        file = Time.now.to_i
        agent.get(m, nil, "http://ameblo.jp/", nil).save("ameba_#{file}.#{$1}")
        url = `./gyazo ameba_#{file}.png`.gsub("\n","")
        File.delete("ameba_#{file}.png")
        "#{url.sub("//","//cache.")}.png"
      end
    end
  }
end
