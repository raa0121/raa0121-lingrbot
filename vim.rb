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
  url = [] 
  title = []
  date = []
  author = []
  count = []
  user = []
  command = event['message']["text"].strip.split(/[\s　]/)
  atnd = JSON.parse(open("http://api.atnd.org/events/?event_id=33746&format=json").read)
  atnd["events"][0]["description"].gsub(/\|(.*)\|(.*)\|(.*)\|"(.*)":(.*)\|/){
    count << $1; date << $2; author << $3; title << $4; url << $5
  }
  query = ['version=2.0.1&' , '&login=raaniconama&apiKey=R_446879b310c0e904023fdda3e0b97998']
  if command[1] == nil
    result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{url.reverse[0]}#{query[1]}").read)
    "#{count.reverse[0]} #{date.reverse[0]} #{author.reverse[0]} #{title.reverse[0]} - #{result["results"][url.reverse[0]]["shortUrl"]}"
  elsif command[1] =~ /^\d+/
    result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{url[command[1].to_i-1]}#{query[1]}").read)
    "#{count[command[1].to_i-1]} #{date[command[1].to_i-1]} #{author[command[1].to_i-1]} #{title[command[1].to_i-1]} - #{result["results"][url[command[1].to_i-1]]["shortUrl"]}"
  elsif command[1] =~ /^(.*)/
    command[1] = event["message"]["speaker_id"] if command[1] == "#me"
    author.zip(count,date,title,url).each{|a,c,d,t,u|
      if a == "@#{command[1]}"
        result = JSON.parse(open("http://api.bit.ly/shorten?#{query[0]}#{u}#{query[1]}").read)
        user << "#{c} #{d} #{a} #{t} - #{result["results"][u]["shortUrl"]}"
      end
    } 
    return user.join("\n")
  end
end

post '/vim' do
  content_type :text
  json = JSON.parse(request.body.string)
  json["events"].select {|e| e['message'] }.map {|e|
    m = e["message"]["text"]
    case m
    when /^!VimAdv/
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
    when /SEGV/ =~ m
      "キャッシュ(笑)"
    else
      nil
    end
  }
end
