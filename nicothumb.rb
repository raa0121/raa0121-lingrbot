#!/usr/bin/ruby
# -*- coding utf-8 -*-
require 'sinatra'
require 'mechanize'
require 'rexml/document'
require 'digest/md5'
require 'dm-core'
require 'dm-migrations'

load './gyazo.rb'


class GyazoCache
  include DataMapper::Resource
  property :id, Serial
  property :image_url, String, :length => 256
  property :gyazo_url, String, :length => 256
end

DataMapper.finalize

configure :production do
  DataMapper.setup(:default, ENV["HEROKU_POSTGRESQL_PURPLE_URL"])
  GyazoCache.auto_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, "yaml:///tmp/thumb")
  GyazoCache.auto_upgrade!
end

class Nicothumb
  def initialize
    @agent = Mechanize.new
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def get_gyazo_image_direct_link(gyazo_url)
    @agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
    @agent.get(gyazo_url)
    image_node = @agent.page.parser.xpath("//meta[@name='twitter:image']").first.attributes["content"]
    unless image_node
      return nil
    else
      image_node.value
    end
  end

  def create_gyazo(greatest_url, referer = nil)
    greatest_url =~ /(jpe?g|gif|png)$/
    ext = $1
    temp_file = "tmpimage_#{Time.now.to_i}.#{ext}"
    referer ||= greatest_url.gsub(/(http:\/\/[^\/]+\/).*$/, '\1')
    @agent.get(greatest_url, nil, referer, nil).save("./#{temp_file}")
    gyazo = Gyazo.new ""
    url = gyazo.upload "#{temp_file}"
    File.delete(temp_file)
    get_gyazo_image_direct_link(url)
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
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    if /^http:\/\/(?:www.)?nico(?:.ms\/|video.jp\/watch\/)((?:nm|sm)?\d+)/ =~ message
      html = @agent.get("http://ext.nicovideo.jp/api/getthumbinfo/#{$1}")
      return unless html
      info = REXML::Document.new html.body
      return unless info.elements['nicovideo_thumb_response']
      thumb_url = info.elements['nicovideo_thumb_response/thumb/thumbnail_url'].text
      begin
        @agent.get(thumb_url +".L")
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          "#{thumb_url}"
        end
      else
        thumb_url += ".L"
      end
      "#{thumb_url}"
    elsif %r|^http://live\.nicovideo\.jp/gate/.*| =~ message
      @agent.get(message)
      "http://live.nicovideo.jp/#{@agent.page.at('div.bn/img')['src']}"
    elsif /^http:\/\/www\.pixiv\.net\/member_illust.php\?(.+)/ =~ message
      params = {}
      $1.split('&').each do |p|
        key, value = p.split('=')
        params[key] = value
      end
      get_pixiv_image_url(message, params)
    elsif %r#^http://[.a-z]+\.c\.yimg\.jp# =~ message and /(jpe?g|gif|png)(\?|$)/ !~ message
      "#{message}#.png"
    elsif %r#http://img\d+\.blogs\.yahoo\.co\.jp/.+/folder/\d+/img_\d+_\d+_\d+# =~ message
      { :mode => :gyazo, :url => message }
    elsif %r#http://(.+-origin\.fc2\.com)/.+\.(jpe?g|gif|png)$# =~ message
      { :mode => :gyazo, :url => message }
    elsif %r#http://stat\.ameba\.jp/user_images/.+\.(jpe?g|gif|png)$# =~ message
      { :mode => :gyazo, :url => message, :referer => 'http://ameblo.jp/' }
    elsif /^http:\/\/twitpic\.com\/[0-9a-z]+/ =~ message
      begin
        @agent.get("#{$&}/full")
        @agent.page.parser.xpath("//div[@id='media-full']/img").first.attributes["src"].value
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif %r#http://instagram\.com/p/[\w-]+/$# =~ message
      begin
        @agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
        @agent.get(message)
        unless @agent.page.parser.xpath("//meta[@property='og:image']").first.attributes["content"]
          return ""
        end
        image_url = @agent.page.parser.xpath("//meta[@property='og:image']").first.attributes["content"].value
        if not @agent.page.parser.xpath("//meta[@property='og:video']").empty?
          "#{image_url}\nwith video"
        else
          image_url
        end
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^http:\/\/seiga.nicovideo.jp\/seiga\/im(\d+)/ =~ message
      "http://lohas.nicoseiga.jp/thumb/#{$1}i"
    elsif /^http:\/\/seiga.nicovideo.jp\/watch\/mg(\d+)/ =~ message
      begin
        @agent.get(message)
        image_url = @agent.page.parser.xpath("//img[@class='thumb']").first.attributes["src"].value
        "#{image_url}#.jpg"
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^https?:\/\/t\.co\/.+/ =~ message
      begin
        original_user_agent = @agent.user_agent
        original_uri = @agent.get(message).uri.to_s 
        @agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
        @agent.get(original_uri)
        @agent.user_agent = original_user_agent
        unless @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img")
          return ""
        end
        @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img").first[1]
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^https:\/\/twitter\.com\/.+\/status\/\d+/ =~ message
      begin
        original_user_agent = @agent.user_agent
        @agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"
        @agent.get(message)
        @agent.user_agent = original_user_agent
        unless @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img")
          return ""
        end
        @agent.page.parser.xpath("//a[contains(@class, 'media-thumbnail')]").at("img").first[1]
      rescue Mechanize::ResponseCodeError => ex
        case ex.response_code
        when '404'
          return ""
        end
      end
    elsif /^http:\/\/d\.pr\/i\/[a-zA-Z0-9]+/ =~ message
      { :mode => :gyazo, :url => "#{message}+" }
    elsif /^[a-zA-Z0-9_.-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]+$/ =~ message # mail address
      # Gravatar returns a default icon if not found
      "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(message)}?size=210"
    end
  end

  def append_image_extension(url)
    if url == ""  
      return ""
    elsif url =~ /\.(png|gif|jpg|jpeg)$/
      url
    else
      "#{url}#.jpg"
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
      cache = GyazoCache.first({:image_url => result[:url]})
      if cache.nil?
        gyazo_url = create_gyazo(result[:url], result[:referer])
        cache = GyazoCache.create(:image_url => result[:url], :gyazo_url => gyazo_url)
      end
      "#{pre_text}#{append_image_extension(cache.gyazo_url)}#{post_text}"
    elsif result.kind_of?(String)
      append_image_extension(result)
    end
  end
end

get '/nicothumb' do
  content_type :text
  "thumb"
end

post '/nicothumb' do
  content_type :text
  response_lines = []
  json = JSON.parse(request.body.read)
  if not json["events"].nil?
    json["events"].select {|e| e['message'] }.map {|e|
      m = e["message"]["text"]
      unless [] == urls = URI.extract(m, ["http", "https"]).reject{|url| url.end_with? '://' }
        thumb = Nicothumb.new
        urls.each do |url|
          response_lines << thumb.do_maji_sugoi(url)
        end
        if [] == response_lines
          return ""
        end
        return response_lines.join("\n")
      end
    }
  end
end
