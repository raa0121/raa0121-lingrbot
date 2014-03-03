# coding : utf-8
require 'mechanize'
require 'open-uri'
require 'cgi'

$agent = Mechanize.new

def post_lingr_http(text, room)
  query = ['&bot=lyrics&text=','&bot_verifier=03a96b624a652e568038c61f336bbb0ba8bd7ed5']
  open("http://lingr.com/api/room/say?room=#{room}#{query[0]}#{CGI.escape(text)}#{query[1]}").read
end

def searchMusic(word)
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

def getLyric(mes,room)
  command = mes.sub("!lyrics","").strip
  lyric_url = searchMusic(command)
  if "" == lyric_url
    return ""
  end
  begin
    lyric_page = $agent.get(lyric_url)
    lyric = $agent.page('p').text.sub(/test1=\d+&test2=/,"")
    if lyric.bytesize > 1000
      lyric.split("\n").each_slice(15){|l| post_lingr_http(l.join("\n"), room)}
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
