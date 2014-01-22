require 'mechanize'
require 'open-uri'
require 'cgi'

def searchMusic(word)
  base_url = "http://www.utamap.com/searchkasi.php?searchname=title&word="
  word = CGI.escape(word)
  keyword = CGI.escape("検   索")
  agent = Mechanize.new
  search = agent.get ("#{base_url}#{word}&act=search&search_by_keyword=#{keyword}&sortname=1&pattern=1")
  id = agent.page.search('td.ct160 a')[0]['href'].sub("./showkasi.php?surl=","")
  return "http://www.utamap.com/phpflash/flashfalsephp.php?unum=#{id}"
end
def getLyric(mes)
  command = mes.sub("!lyrics","").strip
  lyric_url = searchMusic(command[1])
  lyric = open(lyric_url).read.force_encoding("utf-8").sub(/test1=\d+&test2=/,"")
end

post '/lyrics' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    if /^!lyrics/ =~ m
      getLyric(m)
    end
  }
end
