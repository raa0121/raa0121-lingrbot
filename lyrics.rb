# coding : utf-8
require 'mechanize'
require 'open-uri'
require 'cgi'

$agent = Mechanize.new
$agent.user_agent = "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0"

def post_lingr_http(text, room)
  query = ['&bot=lyrics&text=','&bot_verifier=03a96b624a652e568038c61f336bbb0ba8bd7ed5']
  open("http://lingr.com/api/room/say?room=#{room}#{query[0]}#{CGI.escape(text)}#{query[1]}").read
end

def searchMusicUtamap(word)
  base_url = "http://www.utamap.com/searchkasi.php?searchname=title&word="
  word = CGI.escape(word)
  keyword = CGI.escape("検   索")
  begin
    unless Mechanize::Page == $agent.get("#{base_url}#{word}&act=search&search_by_keyword=#{keyword}&sortname=1&pattern=1").class
      return ""
    end
    unless [] == $agent.page.search('td.ct160 a').to_a
      id = $agent.page.search('td.ct160 a')[0]['href'].sub("./showkasi.php?surl=","")
      return "http://www.utamap.com/phpflash/flashfalsephp.php?unum=#{id}"
    end
  rescue Mechanize::ResponseCodeError => ex
    case ex.response_code
    when '403'
      return ""
    when '404'
      return ""
    when '503'
      return ""
    when '500'
      return ""
    end
  end
  return ""
end

def searchMusicKasitime(word)
  base_url = "https://www.google.co.jp/search?q="
  site = CGI.escape("+site:www.kasi-time.com")
  word = CGI.escape(word)
  begin
    unless Mechanize::Page == $agent.get("#{base_url}#{word}#{site}").class
      return ""
    end
    unless [] == $agent.page.search('li.g/h3').to_a
      id = $agent.page.at('li.g/h3/a')['href'].sub("/url?q=http://www.kasi-time.com/item-","").sub(/\.html&.*/,"")
      return "http://www.kasi-time.com/item_js.php?no=#{id}"
    end
  rescue Mechanize::ResponseCodeError => ex
    case ex.response_code
    when '403'
      return ""
    when '404'
      return ""
    when '503'
      return ""
    when '500'
      return ""
    end
  end
  return ""
end

def getLyric(mes,room)
  command = mes.sub("!lyrics","").strip
  lyric_url = searchMusicUtamap(command)
  if "" == lyric_url
    lyric_url = searchMusicKasitime(command)
    if "" == lyric_url
      return "#{command} is Not found."
    end
  end
  begin
    lyric_page = $agent.get(lyric_url)
    if lyric_url.include?("utamap")
      lyric = $agent.page.at('p').text.sub(/test1=\d+&test2=/,"")
    else
      lyric = $agent.page.at('p').text.sub("document.write('","").sub("');","")
    end
    if lyric.bytesize > 1000
      lyric.gsub("\n\n","\n　\n").split("\n").each_slice(15){|l| post_lingr_http(l.join("\n"), room)}
      return ""
    else
      lyric
    end
  rescue Mechanize::ResponseCodeError => ex
    case ex.response_code
    when '403'
      return ""
    when '404'
      return ""
    when '503'
      return ""
    when '500'
      return ""
    end
  end
end

post '/lyrics' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    r = e["message"]["room"]
    if /^!lyrics/ =~ m
      getLyric(m,r)
    end
  }
end

get '/lyrics' do
  content_type :text
  "lyrics"
end
