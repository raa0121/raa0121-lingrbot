# coding : utf-8
require 'mechanize'
require 'open-uri'
require 'cgi'

def post_lingr_http(text, room)
  query = ['&bot=lyrics&text=','&bot_verifier=03a96b624a652e568038c61f336bbb0ba8bd7ed5']
  open("http://lingr.com/api/room/say?room=#{room}#{query[0]}#{CGI.escape(text)}#{query[1]}").read
end

def searchMusic(word)
  base_url = "http://www.utamap.com/searchkasi.php?searchname=title&word="
  word = CGI.escape(word)
  keyword = CGI.escape("検   索")
  agent = Mechanize.new
  search = agent.get ("#{base_url}#{word}&act=search&search_by_keyword=#{keyword}&sortname=1&pattern=1")
  id = agent.page.search('td.ct160 a')[0]['href'].sub("./showkasi.php?surl=","")
  return "http://www.utamap.com/phpflash/flashfalsephp.php?unum=#{id}"
end

def getLyric(mes,room)
  command = mes.sub("!lyrics","").strip
  lyric_url = searchMusic(command)
  lyric = open(lyric_url).read.force_encoding("utf-8").sub(/test1=\d+&test2=/,"")
  if lyric.bytesize > 1000
    post_lingr_http(lyric.split(/\n/)[0..15].join("\n"), room)
    "#{lyric.split(/\n/)[16..-1].join("\n")}"
  else
    lyric
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
