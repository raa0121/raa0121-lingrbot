require 'sinatra'
#require "json"
#require "cgi"

#json = JSON.parse(CGI.new["json"])

get '/' do
	'hello world'
	#if /(^d*)d(^d*)/ =~ json["events"]["message"]["text"] do
	#	print "Content-Type: text/plain\n\n"
	#	$1.times do
	#			print rand($2-1)+1
	#end
end
