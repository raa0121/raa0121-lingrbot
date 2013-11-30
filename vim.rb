# -*- coding : utf-8 -*-
#require "sinatra"
require "json"
require "open-uri"
require "mechanize"
require 'cgi'

VAC12="https://raw.github.com/osyo-manga/vim_advent_calendar2012/master/README.md"
VAC13="https://raw.github.com/osyo-manga/vim_advent_calendar2013/master/README.md"

get '/vim' do
  "VimAdv"
end

agent = Mechanize.new

def post_lingr_http(text, room)
  open("http://lingr.com/api/room/say?room=#{room}&bot=VimAdv&text=#{CGI.escape(text)}&bot_verifier=f970a5aec3cbd149343aa5a4fec3a43e68d01e4a").read
end

def post_bitly(url)
  query = ['version=2.0.1&longUrl=', '&login=raaniconama&apiKey=R_446879b310c0e904023fdda3e0b97998']
  open("http://api.bit.ly/shorten?#{query[0]}#{url}#{query[1]}").read
end

def split_ranking(ranking)
  ranking.group_by{|i,j|j}.map{|a|a[1]}.map{|a|a.map{|a|a.reverse}.join("").sub(/^(\d+)/){i="%02d"%($1.to_i);"#{i}回:"}.gsub(/\d@/,", @")}.join("\n")
end

def ranking(data, rank)
  ranking_data = data.map {|v| v[1]["author"]}.each_with_object(Hash.new(0)){|o,h|h[o]+=1}.sort_by{|o,h|h}.reverse
  if rank > 50
    post_lingr_http(split_ranking(ranking_data[0..50]))
    "#{split_ranking(ranking_data[51..rank-1])}"
  else
    "#{split_ranking(ranking_data[0..rank-1])}"
  end
end

def VimAdv(event, year)
  if /13/ =~ year
    atnd_url = "http://atnd.org/events/45072"
  else
    atnd_url = "http://atnd.org/events/33746"
  end
  data = Hash.new
  user = [];search=[]
  command = event['message']["text"].strip.split(/[\s　]/)
  room = event['message']['room']
  #atnd = JSON.parse(open("http://api.atnd.org/events/?event_id=33746&format=json").read)
  #descript = atnd["events"][0]["description"].split("\r\n")
  descript = open(year).read.split("\n")
  descript.map{|m| m.match(/\|(.*)\|(.*)\|(.*)\|(?:"(.*)":(.*))?\|/) {|m|
    data[m[1]] = {"count" => m[1], "date" => m[2], "author" => m[3], "title" => m[4], "url" => m[5]}
  }}
  data = data.sort
  data, schedule = data.partition{|d| d[1]["title"]} 
  reserved =  schedule.map{|m|m.select{|n|n["author"]=="@"}}.count([])
  schedule = schedule[0..(reserved + 4)]
  case command[1]
  when nil
    if data.none?
      return "#{schedule.map{|s| "#{s[1]["count"]} #{s[1]["date"]} #{s[1]["author"]}"}.join("\n")}\n#{atnd_url}"
    end
    last = data[-1][-1]
    schedule = schedule[0..2].map{|s| "#{s[1]["count"]} #{s[1]["date"]} #{s[1]["author"]}"}.join(" ")
    result = JSON.parse(post_bitly(last["url"]))
    "#{last["count"]} #{last["date"]} #{last["author"]} #{last["title"]} - #{result["results"][last["url"]]["shortUrl"]}\nNext:#{schedule}\n#{atnd_url}"
  when /^\d+/
    day = data[command[1].to_i-1][-1]
    result = JSON.parse(post_bitly(day["url"]))
    "#{day["count"]} #{day["date"]} #{day["author"]} #{day["title"]} - #{result["results"][day["url"]]["shortUrl"]}"
  when /#ranking(\d+)?/ 
    rank = 10 if $1 == nil && command[2] == nil 
    rank = $1.to_i if $1.to_i > 0
    rank = command[2].to_i if command[2].to_i > 0
    ranking(data, rank) 
  when /#next/
    "#{schedule.map{|s| "#{s[1]["count"]} #{s[1]["date"]} #{s[1]["author"]}"}.join("\n")}\n#{atnd_url}"
  when /^(.*)/
    command[1] = event["message"]["speaker_id"] if command[1] == "#me"
    command[1] = "ujihisa" if command[1] == "u"
    data.map {|v|
      if /#{command[1]}/ =~ v[-1]["author"]
        result = JSON.parse(post_bitly(v[-1]["url"]))
        user << "#{v[-1]["count"]} #{v[-1]["date"]} #{v[-1]["author"]} #{v[-1]["title"]} - #{result["results"][v[-1]["url"]]["shortUrl"]}"
      end
    }
    if user.length >= 10 
      post_lingr_http("合計 #{user.length}件\n#{user[0..-9].join("\n")}",room)
      return user[-10..-1].join("\n")
    elsif user.length > 0
      return "合計 #{user.length}件\n#{user.join("\n")}"
    else
      data.map {|v|
        if /#{command[1]}/ =~ v[-1]["title"]
          result = JSON.parse(post_bitly(v[-1]["url"]))
          search << "#{v[-1]["count"]} #{v[-1]["date"]} #{v[-1]["author"]} #{v[-1]["title"]} - #{result["results"][v[-1]["url"]]["shortUrl"]}"
        end
      }
      if search.length >= 10
        post_lingr_http("合計 #{search.length}件\n#{search[0..9].join("\n")}",room)
        return search[10..-1].join("\n")
      elsif search.length > 0
        return "合計 #{search.length}件\n#{search.join("\n")}"
      end
    end
  end
end


post '/vim' do
  content_type :text
  json = JSON.parse(request.body.read)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    case m
    when /^(!VimAdv12|:vimadv12|!VAC12)/i
      VimAdv(e,VAC12)
    when /^(!VimAdv|:vimadv|!VAC)/i
      VimAdv(e,VAC13)
    when /^:vimhacks?$/i
      agent.get("http://vim-users.jp/category/vim-hacks/")
      return agent.page.search('h2 a').map{|e| "#{e.inner_text} - #{e['href']}"}[0,3].join("\n")
    when /^:vimhacks\s+?(\d+)\b/i
      agent.get("http://vim-users.jp/hack#{$1}")
      return "#{agent.page.search('h1').inner_text} - #{agent.page.uri}"
    when /^:vimhacks\s+?(.*)\b/i
      agent.get("http://vim-users.jp/?s=#{CGI.escape($1)}&cat=19")
      return agent.page.search('h2 a').map{|e| "#{e.inner_text} - #{e['href']}"}.select{|s| /hack/ =~ s}.join("\n")
    when /^またMacVimか$/
      return 'http://bit.ly/f2fjvZ#.png'
    when /SEGV/i
      return "キャッシュ(笑)"
    else
      nil
    end
  }.compact.join
end
