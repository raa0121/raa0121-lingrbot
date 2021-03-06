# coding : utf-8
require 'mechanize'
require 'open-uri'
require 'cgi'
require 'json'
require 'base64'
require 'htmlentities'

$agent = Mechanize.new
$agent.user_agent = "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:50.0) Gecko/20100101 Firefox/50.0"

def post_lingr_http_lyrics(text, room)
  query = ['&bot=lyrics&text=','&bot_verifier=03a96b624a652e568038c61f336bbb0ba8bd7ed5']
  open("http://lingr.com/api/room/say?room=#{room}#{query[0]}#{CGI.escape(text)}#{query[1]}").read
end

def searchMusicUtanet(word)
  base_url = "https://www.google.co.jp/search?q="
  svg_base_url = "http://www.uta-net.com"
  site = CGI.escape("site:www.uta-net.com")
  intitle = CGI.escape(" intitle:")
  word = CGI.escape(word.strip.split.map{|it| %`"#{it}"`}.join(" "))
  ids = []
  titles = []
  artists = []
  urls = []
  lyrics = []
  result = {}
  begin
    unless Mechanize::Page == $agent.get("#{base_url}#{site}#{intitle}#{word}&ie=utf-8&oe=utf-8&hl=ja").class
      return {}
    end
    unless [] == search_urls = $agent.page.search('cite').map(&:inner_text)
      search_urls.select{|u|
        if /(www\.uta-net\.com\/song\/\d+\/)/ =~ u
          url = "#{u.sub("/url?q=", "").sub(/(\song\/\d+\/).*/,"\1").sub(/^(www)/, 'http://\1')}"
          $agent.get(url)
          titles << $agent.page.at('#view_kashi .title h2').text
          artists << $agent.page.at('.kashi_artist span').text
          lyrics << $agent.page.at('#kashi_area').inner_html.gsub('<br>', "\n")
          urls << url
        end
      }
    end
  rescue Mechanize::ResponseCodeError => ex
    return {}
  end
  result = {lyrics: lyrics.first, url: urls.first,
            title: titles.first, artist: artists.first}
  if result[:url] == nil
    return {}
  end
  return result
end

def searchMusicUtamap(word)
  base_url = "http://www.utamap.com/searchkasi.php?searchname=title&word="
  lyrics_base_url = "http://www.utamap.com/phpflash/flashfalsephp.php?unum="
  word = CGI.escape(word)
  keyword = CGI.escape("検   索")
  error_word = "エラー120：管理人にご連絡ください。"
  result = {}
  begin
    unless Mechanize::Page == $agent.get("#{base_url}#{word}&act=search&search_by_keyword=#{keyword}&sortname=1&pattern=1").class
      return {}
    end
    unless [] == $agent.page.search('td.ct160 a').to_a
      title = $agent.page.search('td.ct160 a')[0].text
      artist = $agent.page.search('td.ct120')[0].text
      id = $agent.page.search('td.ct160 a')[0]['href'].sub("./showkasi.php?surl=","")
      url = $agent.page.search('td.ct160 a')[0]['href'].sub(".","http://www.utamap.com/")
    end
  rescue Mechanize::ResponseCodeError => ex
    return {}
  end
  lyrics_page = open("#{lyrics_base_url}#{id}").read
  begin
    if lyrics_page.encode("UTF-8", "Shift_JIS") == error_word
      return {}
    end
  rescue
    lyrics = CGI.unescapeHTML(lyrics_page.force_encoding("UTF-8")).sub(/test1=\d+&test2=/,"")
    result = {lyrics: lyrics, url: url,
              title: title, artist: artist}
    if result[:url] == nil
      return {}
    end
  end
  return result
end

def searchMusicKasitime(word)
  base_url = "https://www.google.co.jp/search?q="
  site = CGI.escape("site:www.kasi-time.com")
  intitle = CGI.escape(" intitle:")
  word = CGI.escape(word.strip.split.map{|it| %`"#{it}"`}.join(" "))
  ids = []
  titles = []
  artists = []
  urls = []
  result = {}
  begin
    unless Mechanize::Page == $agent.get("#{base_url}#{site}#{intitle}#{word}&ie=utf-8&oe=utf-8&hl=ja").class
      return {}
    end
    unless [] == search_urls = $agent.page.search('cite').map(&:inner_text)
      search_urls.select{|u|
        if /(www\.kasi-time\.com\/item-\d+\.html)/ =~ u
          url = "#{u.sub("/url?q=","").sub(/\.html.*/,".html").sub(/^(www)/, 'http://\1')}"
          $agent.get(url)
          titles << $agent.page.search('//div[@class="person_list_and_other_contents"]/h1').text.strip
          artists << $agent.page.search('//div[@class="person_list"]//th[text()="歌手"]/following-sibling::td').text.gsub(/\n\t+/,'').gsub('　', ' ').split('関連リンク:').first.strip
          urls << url
        end
      }
    end
  rescue Mechanize::ResponseCodeError => ex
    return {}
  end
  begin
    lyrics_page = open("#{urls[0]}").read
    lyrics = HTMLEntities.new.decode(lyrics_page[/var lyrics = '(.+)';/, 1]).gsub("<br>","\n")
    if lyrics.include? "<table>"
      lyrics = Nokogiri::HTML.parse(lyrics).search('tr th').zip(Nokogiri::HTML.parse(lyrics).search('tr td')).map{|i|i.join(' : ').strip}.join("\n")
    end
    result = {lyrics: lyrics, url: urls.first,
              title: titles.first, artist: artists.first}
  rescue => ex
    return {}
  end
  return result
end

def searchMusicPetitLyrics(word)
  base_url = "http://petitlyrics.com"
  search_url = "#{base_url}/search_lyrics?title="
  word = CGI.escape(word)
  ids = []
  titles = []
  artists = []
  urls = []
  result = {}
  begin
    unless Mechanize::Page == $agent.get("#{search_url}#{word}").class
      return {}
    end
    unless [] == search_urls = $agent.page.search('span.lyrics-list-title').to_a.map{|u|u.parent["href"]}
      search_urls.map{|u|
        ids << u.sub("/lyrics/","")
        url = "#{base_url}#{u}"
        $agent.get(url)
        info = $agent.page.at('.title-bar').text.split('/')
        urls << url
        titles << info.first.chop
        artists << info.last.chop
      }
    end
  rescue Mechanize::ResponseCodeError => ex
    return {}
  end

  begin
    res = $agent.post("#{base_url}/com/get_lyrics.ajax",
                      { lyrics_id: ids.first },
                      { 'X-Requested-With' => 'XMLHttpRequest'})
    data = JSON.parse(res.body)
    lyrics = data.inject('') {|acc, line|
        acc += Base64.decode64(line['lyrics'])
        acc + "\n"
    }.force_encoding("UTF-8").strip

    result = {lyrics: lyrics, url: urls.first,
              title: titles.first, artist: artists.first}
    return result
  rescue Mechanize::ResponseCodeError => ex
    return {}
  end
end

def getLyric(mes,room)
  command = mes.sub("!lyrics","")
  lyrics_info = searchMusicUtanet(command)
  if {} == lyrics_info
    lyrics_info = searchMusicUtamap(command)
    if {} == lyrics_info
      lyrics_info = searchMusicKasitime(command)
      if {} == lyrics_info
        return "#{command} is Not found."
      end
    end
  end
  lyrics = "title:#{lyrics_info[:title]}\nartist:#{lyrics_info[:artist]}\nurl:#{lyrics_info[:url]}\n\n#{lyrics_info[:lyrics]}"
  if lyrics.bytesize > 1000
    lyrics.gsub("\n\n","\n　\n").split("\n").each_slice(15){|l| post_lingr_http_lyrics(l.join("\n"), room)}
    return ""
  else
    lyrics
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
