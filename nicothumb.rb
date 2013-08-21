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

def get_pixiv(agent, pixiv)
  file = Time.now.to_i
  agent.get(pixiv, nil,
            "http://www.pixiv.net",
            nil).save("./pixiv_#{file}.png") 
  url = `./gyazo pixiv_#{file}.png`.gsub("\n","")
  File.delete("pixiv_#{file}.png")
  "#{url.sub("//","//cache.")}.png"
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
      elsif /^http:\/\/www.pixiv.net\/member_illust.php\?(.+)/ =~ m
        params = {}
        $1.split('&').each do |p|
          key, value = p.split('=')
          params[key] = value
        end
        if not params['id'].empty?
          agent.get("http://www.pixiv.net/member.php?id=#{params['id']}")
          name = agent.page.at('h1.name').content
          pixiv = agent.page.at('img.user-image').attributes["src"].value
          image = get_pixiv(agent, pixiv)
          "#{name}\n#{image}"
        elsif (not params['mode'].nil?) and (not params['mode'].empty?)
          agent.get(m)
          case params['mode']
          when 'medium', 'big'
            pixiv = agent.page.at('a.medium-image').children[0].attributes["src"].value
          when 'manga'
            pixiv = agent.page.parser.xpath('//img[@data-filter="manga-image"]')[0].attributes["data-src"].value
          when 'manga_big'
            pixiv = agent.page.parser.xpath("//img[@data-filter='manga-image' and @data-index='#{params['page']}']")[0].attributes["data-src"].value
          end
          if not pixiv.nil?
            get_pixiv(agent, pixiv)
          end
        end
      elsif %r#http://stat\.ameba\.jp/user_images/.+\.(jpe?g|gif|png)$# =~ m
        file = Time.now.to_i
        type = $1.to_str
        open("./ameba_#{file}.#{$1}", 'wb') do |file|
          open(m, 'Referer' => 'http://ameblo.jp/') do |data|
            file.write(data.read)
          end
        end
        url = `./gyazo ameba_#{file}.#{type}`.gsub("\n","")
        File.delete("ameba_#{file}.#{type}")
        "#{url.sub("//","//cache.")}.png"
      elsif /^http:\/\/twitpic.com\/[0-9a-z]+/ =~ m
        agent.get("#{$&}/full")
        agent.page.parser.xpath("//div[@id='media-full']/img").first.attributes["src"].value
      elsif /^http:\/\/seiga.nicovideo.jp\/seiga\/im(\d+)/ =~ m
        "http://lohas.nicoseiga.jp/thumb/#{$1}i#.jpg"
      elsif /^https:\/\/twitter.com\/.+\/status\/\d+\/photo\/1/ =~ m
        agent.get(m)
        agent.page.parser.xpath("//img[@class='large media-slideshow-image']")[0].attributes["src"].value + "#.jpg"
      end
    end
  }
end
