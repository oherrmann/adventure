# 
# 
# Ruby Cave Game grammar and text manipulation code
# 
# This file is for code that maipulates text to interface with the user.
# 
#
module Adventure

	COLORS = [ :red, :orange, :yellow, :green, :blue, :purple, :brown, :black, :white,
		:grey, :gold, :silver, :copper, :beige, :tan, :magenta, :maroon ]

	$abbr = {
		:n=>"north", :s=>"south", :e=>"east", :w=>"west",
		:ne=>"northeast", :nw=>"northwest",
		:se=>"southeast", :sw=>"southwest",
		:u=>"up",:d=>"down",
		:i=>"in",:o=>"out"
	}
	
	$long = {
		:north=>:n,:south=>:s,:east=>:e,:west=>:w,
		:northeast=>:ne,:southeast=>:se,
		:northwest=>:nw,:southwest=>:sw,
		:"in"=>:i, :out=>:o, :up=>:u, :down=>:d
	}
	
	$directions = [ 
		"north", "northeast","east","southeast",
		"south","southwest","west","northwest"
	]
	
	$directions_all = [ 
		"north", "northeast","east","southeast",
		"south","southwest","west","northwest",
		"up","down"
	]

	$GAME_ADJ = []
	
	def Adventure::reverse_direction( direction )
		{:north=>:south, :northeast=>:southwest, :east=>:west,
			:southeast=>:northwest, :south=>:north, :southwest=>:northeast,
			:west=>:east,:northwest=>:southeast,:up=>:down,:down=>:up,
			:in=>:out,:out=>:in}[ direction.to_sym ]
	end
	
	$cardinal_numbers = [
		:one, :two, :three, :four, :five, :six, :seven, :eight, :nine, :ten,
		:eleven, :twelve, :thirteen, :fourteen, :fifteen, :sixteen, :seventeen,
		:eighteen, :nineteen, :twenty
	]
	$ordinal_numbers = {
		:first=>1, :second=>2, :third=>3, :fourth=>4, :fifth=>5, 
		:sixth=>6, :seventh=>7, :eighth=>8, :ninth=>9, tenth=>10
	}
	
	# If there are three choices in a line, the first is "l", the middle/center is "c",
	# and the last/rightmost is "r". TODO: A way to specify "second from left" or
	# "third from last".
	$lcr = {
		:left=>"a",:middle=>"c",:center=>"c", :right=>"b", :last=>"b"
	}
	
	Adventure::exit_list( text , num_choices )
		offset = 0
		position = ""
		result = -1
		if text.length == 3 && text[1] = "from"
			offset = ( $ordinal_numbers[ text[0].to_sym ] ) - 1
			pos = $lcr[ text[0].to_sym ]
			a = 1; b = num_choices
			op = pos == "l" ? "+" : "-"
			return result if pos == "c"
			begin
				result = eval(pos + op + offset.to_s)
			rescue
				return -1
			end
		end
		return result
	end
	
	# list_to_english takes a array of items and lists them in human-readable fashion.
	# For example, list_to_english( ["a","b","c"] ) should be rendered as:
	# "a, b, and c"
	def Adventure::list_to_english( text )
		#peval {"text"}
		items = text.length
		if items == 0 then return "" end
		if items == 1 then return text[0] end
		if items == 2 then return text[0] + " and " + text[1] end
		result = ""
		(items-2).times do |x| 
			result += ( text[x] + ", " )
		end
		# Added the Oxford comma below.
		result += text[ items - 2 ] + ", and " + text[ items - 1 ]
		return result
	end
	
	# Returns "n" for "north", etc, or false if this is not a valid direction.
	# Adventure::is_direction?( "north" ) => "n"
	def Adventure::is_direction?( text )
		result = $long[text.to_sym] if text
		return result.to_s if result
		return false
	end
	
	# Converts "n" to "north", etc., or false if this is not a valid direction abbreviation
	# Adventure::to_direction( "n" ) => "north"
	def Adventure::to_direction( text )
		result = $abbr[text.to_sym]
		return result if result
		return false
	end

	# Returns a textual timestamp. Uses config argument for "us" for United States format (month.day.year), 
	# else uses Canadian format ( day.month.year).
	def Adventure::ts(format)
		dt = DateTime.now
		if format == "us"
			day = [dt.month,dt.day]
		else
			day = [dt.day,dt.month]
		end
		return "%0.2d.%0.2d.%d %0.2d:%0.2d:%0.2d" % ( day + [dt.year,dt.hour,dt.min,dt.sec] )
	end
	
	# The adjust_english method takes command strings entered by the user and adjusts them
	# to commands understood by the game.
	def Adventure::adjust_english( text )
		adj = []
		text.gsub!(/ the | a /," ")
		text.gsub!(/^pick up|^grab/,"take")
		text.gsub!(/^@/,"goto")
		text.gsub!(/^&/,"inspect")
		text.gsub!(/^discard/,"drop")
		text.gsub!(/^what/,"what")
		text.gsub!(/^move/,"go")
		text.gsub!(/^drink|^eat/,"consume")
		text.gsub!(/ any /) do |match| adj << $&; ' ' end
		text.gsub!(/^climb|^swim|^run/) do 
			|match|
			adj << $&
			"go"
		end
		text.squeeze!(" ")
		$GAME_ADJ = adj
		#puts 'adjectives = ' + $GAME_ADJ.pretty
		#puts 'text = ' + text.pretty
		return text,adj
	end

	
	# A random number generator
	class Die
		def Die.roll( max )
			return rand( max ) + 1
		end
	end # Die class
	
end # Adventure module
