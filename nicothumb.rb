#!/usr/bin/ruby
# -*- coding utf-8 -*-
require 'sinatra'
require "mechanize"
require 'rexml/document'
require 'digest/md5'

class Nicothumb
  def initialize
    @agent = Mechanize.new
  end

  def create_gyazo(greatest_url, referer = nil)
    greatest_url =~ /(jpe?g|gif|png)$/
    ext = $1
    temp_file = "tmpimage_#{Time.now.to_i}.#{ext}"
    referer ||= greatest_url.gsub(/(http:\/\/[^\/]+\/).*$/, '\1')
    @agent.get(greatest_url, nil, referer, nil).save("./#{temp_file}")
    url = `./gyazo #{temp_file}`.gsub("\n","")
    File.delete(temp_file)
    "#{url.sub("//","//cache.")}.png"
  end

  def get_pixiv_image_url(message, params)
    if (not params['id'].nil?) and (not params['id'].empty?)
      @agent.get("http://www.pixiv.net/member.php?id=#{params['id']}")
      name = @agent.page.at('h1.name').content
      pixiv = @agent.page.at('img.user-image').attributes["src"].value
      { :mode => :gyazo, :url => pixiv, :pre_text => name }
    elsif (not params['mode'].nil?) and (not params['mode'].empty?)
      @agent.get(message)
      case params['mode']
      when 'medium', 'big'
        pixiv = @agent.page.at('a.medium-image').children[0].attributes["src"].value
      when 'manga'
        pixiv = @agent.page.parser.xpath('//img[@data-filter="manga-image"]')[0].attributes["data-src"].value
      when 'manga_big'
        pixiv = @agent.page.parser.xpath("//img[@data-filter='manga-image' and @data-index='#{params['page']}']")[0].attributes["data-src"].value
      end
      if not pixiv.nil?
        { :mode => :gyazo, :url => pixiv }
      end
    end
  end

  def get_image_url(message)
    if /^http:\/\/(www.)?nico(.ms\/|video.jp\/watch\/)(.*)?.*$/ =~ message
      html = @agent.get("http://ext.nicovideo.jp/api/getthumbinfo/#{$3}")
      return unless html
      info = REXML::Document.new html.body
      return unless info.elements['nicovideo_thumb_response']
      "#{info.elements['nicovideo_thumb_response/thumb/thumbnail_url'].text}\#.jpg"
    elsif /^http:\/\/www.pixiv.net\/member_illust.php\?(.+)/ =~ message
      params = {}
      $1.split('&').each do |p|
        key, value = p.split('=')
        params[key] = value
      end
      get_pixiv_image_url(message, params)
    elsif %r#http://stat\.ameba\.jp/user_images/.+\.(jpe?g|gif|png)$# =~ message
      { :mode => :gyazo, :url => message, :referer => 'http://ameblo.jp/' }
    elsif /^http:\/\/twitpic.com\/[0-9a-z]+/ =~ message
      @agent.get("#{$&}/full")
      @agent.page.parser.xpath("//div[@id='media-full']/img").first.attributes["src"].value
    elsif /^http:\/\/seiga.nicovideo.jp\/seiga\/im(\d+)/ =~ message
      "http://lohas.nicoseiga.jp/thumb/#{$1}i#.jpg"
    elsif /^https:\/\/twitter.com\/.+\/status\/\d+\/photo\/1/ =~ message
      @agent.get(message)
      @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]/img").first.attributes["src"].value + "#.jpg"
    elsif /^[a-zA-Z0-9_.-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]+$/ =~ message # mail address
      # Gravatar returns a default icon if not found
      "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(message)}?size=210#.jpg"
    end
  end

  def do_maji_sugoi(message)
    result = get_image_url(message)
    if result.kind_of?(Hash) and result[:mode] == :gyazo
      if result[:pre_text].nil?
        pre_text = ""
      else
        pre_text = "#{result[:pre_text]}\n"
      end
      if result[:post_text].nil?
        post_text = ""
      else
        post_text = "\n#{result[:post_text]}"
      end
       "#{pre_text}#{create_gyazo(result[:url], result[:referer])}#{post_text}"
    elsif result.kind_of?(String)
      result
    end
  end
end

get '/nicothumb' do
  content_type :text
  "thumb"
end

post '/nicothumb' do
  content_type :text
  json = JSON.parse(request.body.string)
  if not json["events"].nil?
    json["events"].map do |e|
      if e["message"]
        thumb = Thumb.new
        thumb.do_maji_sugoi(e["message"]["text"])
      end
    end
  end
end
