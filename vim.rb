# -*- coding : utf-8 -*-
require "sinatra"
require "json"
require "open-uri"

get '/vim' do
  "VimAdv & :help"
end

docroot = "./doc"
jadocroot = "./ja-doc"
tags = open("#{docroot}/tags").read.lines.map {|l| l.chomp.split("\t", 3) }
jatags = open("#{jadocroot}/tags").read.lines.map {|l| l.chomp.split("\t", 3) }

post '/vim' do
  content_type :text
  json = JSON.parse(request.body.string)
  url = [] 
  title = []
  date = []
  author = []
  count = []
  counter = 0
  json["events"].map{|e|
    if e["message"]
      m = e["message"]["text"]
      if /^!VimAdv/ =~ m
        command = m.strip.split(/[\s　]/)
        event = JSON.parse(open("http://api.atnd.org/events/?event_id=33746&format=json").read)
        event["events"][0]["description"].gsub(/\|(.*)\|(.*)\|(.*)\|"(.*)":(.*)\|/){
          count << $1
          date << $2
          author << $3
          title << $4
          url << $5
        }
        if command[1] == nil 
          return "#{count.reverse[0]} #{date.reverse[0]} #{author.reverse[0]} #{title.reverse[0]} - #{url.reverse[0]}"
        elsif command[1] =~ /^\d+/
          return "#{count[command[1].to_i-1]} #{date[command[1].to_i-1]} #{author[command[1].to_i-1]} #{title[command[1].to_i-1]} - #{url[command[1].to_i-1]}"
        elsif command[1] =~ /^(.*)/
          author.each do |a|
            if a == command[1]
              counter+=1
            end
          end
          return "#{command[1]} was written #{counter} times."
        end
      elsif /^:h(elp)?/ =~ m
        help = m.strip.split(/[\s　]/)
        if help[1] =~ /@ja/
          docroot = jadocroot
          t = jatags.select {|t| t[0] == help[1]}.first
          t[2].sub! /.txt$/, 'jax'
        end
        t = tags.select {|t| t[0] == help[1]}.first
        if t
          text = open("#{docroot}/#{t[1]}").read
          text = text[/^.*(?:\s+\*[^\n\s]+\*)*\s#{Regexp.escape(t[2][1..-1])}(?:\s+\*[^\n\s]+\*)*$/.match(text).begin(0)..-1]
          l = /\n(.*\s+\*[^\n\s]+\*|\n=+)$/.match(text)
          text = text[0.. (l ? l.begin(0) : -1)]
          return text
        else
          return 'http://gyazo.com/f71ba83245a2f0d41031033de1c57109.png'
        end
      end
    end
  }
end
