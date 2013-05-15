#!/usr/bin/ruby
# -*- coding utf-8 -*-
require 'sinatra'
require "mechanize"
require 'rexml/document'

agent = Mechanize.new

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
        agent.get(pixiv).save_as("./pixiv_#{file}.png") 
        url = `/app/gyazo pixiv_#{file}.png`.gsub("\n","")
        "#{url}"
     end
    end
  }
end
