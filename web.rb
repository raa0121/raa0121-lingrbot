require 'sinatra'
require "json"
require "cgi"

json = JSON.parse(CGI.new["json"])

get '/' do
	'hello world'
	if /(^d*)d(^d*)/ =~ json["events"]["message"]["text"] 
		print "Content-Type: text/plain\n\n"
		$1.times do
			 rand($2-1)+1
	end
end
