# -*- coding : utf-8 -*-
#require "sinatra"
require "json"
require "open-uri"
require "mechanize"
require 'cgi'

get '/vim' do
  "VimAdv & :help"
end

docroot = "./doc"
jadocroot = "./ja-doc"
tags = File.read("#{docroot}/tags").lines.map {|l| l.chomp.split("\t", 3) }
agent = Mechanize.new

def Help(m,docroot,jadocroot,tags)
  help = m.strip.split(/[\s　]/)
  t = tags.detect {|t| t[0] == help[1].sub(/@ja/,"").sub("+","\\+")}
  if help[1] =~ /@ja/
    docroot = jadocroot
    t[1].sub! /.txt$/, '.jax'
  end
  if t
    text = File.read("#{docroot}/#{t[1]}")
    text = text[/^.*(?:\s+\*[^\n\s]+\*)*\s#{Regexp.escape(t[2][1..-1])}(?:\s+\*[^\n\s]+\*)*$/.match(text).begin(0)..-1]
    l = /\n(.*\s+\*[^\n\s]+\*|\n=+)$/.match(text)
    text = text[0.. (l ? l.begin(0) : -1)]
    docroot = './doc'
    t[1].sub! /.jax$/, '.txt'
    return text
  else
    return 'http://gyazo.com/f71ba83245a2f0d41031033de1c57109.png'
  end
end

def VimAdv(event)
  data = Hash.new
  command = event['message']["text"].strip.split(/[\s　]/)
  room = event['message']['room']
  atnd = JSON.parse(open("http://api.atnd.org/events/?event_id=33746&format=json").read)
  atnd["events"][0]["description"].gsub(/\|(.*)\|(.*)\|(.*)\|"(.*)":(.*)\|/){
    data[$1] = {"count" => $1, "date" => $2, "author" => $3, "title" => $4, "url" => $5}
  }
  data = data.sort
  query = ['version=2.0.1&longUrl=', '&login=raaniconama&apiKey=R_446879b310c0e904023fdda3e0b97998']
  if command[1] == nil
    last = data[-1][-1]
    result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{last["url"]}#{query[1]}").read)
    "#{last["count"]} #{last["date"]} #{last["author"]} #{last["title"} - #{result["results"][last["url"]]["shortUrl"]}"
  elsif command[1] =~ /^\d+/
    day = data["%03d"%command[1]][-1]
    result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{day["url"]}#{query[1]}").read)
    "#{day["count"]} #{day["date"]} #{day["author"]} #{day["title"]} - #{result["results"][day["url"]]["shortUrl"]}"
  elsif command[1] =~ /^(.*)/
    command[1] = event["message"]["speaker_id"] if command[1] == "#me"
    command[1] = "mattn_jp" if command[1] == "mattn"
    command[1] = "ujihisa" if command[1] == "u"
    data.map{|v|
      if v[-1]["author"] == "@#{command[1]}"
        result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{v[-1]["url"]}#{query[1]}").read)
        user << "#{v[-1]["count"]} #{v[-1]["date"]} #{v[-1]["author"} #{v[-1]["title"} - #{result["results"][v[-1]["url"]]["shortUrl"]}"
      end
    }
    if user.length >= 10 
      split = JSON.parse(open("http://lingr.com/api/room/say?room=#{room}&bot=VimAdv&text=#{CGI.escape("合計 #{user.length}件\n#{user[0..9].join("\n")}")}&bot_verifier=f970a5aec3cbd149343aa5a4fec3a43e68d01e4a").read)
      return user[10..-1].join("\n")
    else
      return "合計 #{user.length}件\n#{user.join("\n")}"
    end
  end
end

post '/vim' do
  content_type :text
  json = JSON.parse(request.body.string)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    case m
    when /^(!VimAdv|:vimadv)/
      VimAdv(e)
    when /^:h(elp)?/
      Help(m,docroot,jadocroot,tags)
    when /^:vimhacks$/
      agent.get("http://vim-users.jp/category/vim-hacks/")
      return agent.page.search('h2 a').map{|e| "#{e.inner_text} - #{e['href']}"}[0,3].join("\n")
    when /^:vimhacks\s+?(\d+)\b/
      agent.get("http://vim-users.jp/hack#{$1}")
      return "#{agent.page.search('h1').inner_text} - #{agent.page.uri}"
    when /^:vimhacks\s+?(.*)\b/
      agent.get("http://vim-users.jp/?s=#{CGI.escape($1)}&cat=19")
      return agent.page.search('h2 a').map{|e| "#{e.inner_text} - #{e['href']}"}.select{|s| /hack/ =~ s}.join("\n")
    when /^またMacVimか$/
      return 'http://bit.ly/f2fjvZ#.png'
    when /SEGV/
      return "キャッシュ(笑)"
    else
      nil
    end
  }
end
