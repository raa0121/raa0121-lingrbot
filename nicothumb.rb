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
      if /^http:\/\/(www.)?nico(.ms\/|video.jp\/watch\/)((sm|nm|so)\d+)$/ =~ m
        html = agent.get("http://ext.nicovideo.jp/api/getthumbinfo/#{$3}")
        next unless html
        info = REXML::Document.new html.body
        next unless info.elements['nicovideo_thumb_response']
        "#{info.elements['nicovideo_thumb_response/thumb/thumbnail_url'].text}\#.jpg"
     end
    end
  }
end
