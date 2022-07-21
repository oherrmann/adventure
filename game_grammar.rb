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
	
	# A list of the directions, less up and down
	$directions = [ 
		"north", "northeast","east","southeast",
		"south","southwest","west","northwest"
	]
	
	# A list of the directions, imcluding up and down
	$directions_all = [ 
		"north", "northeast","east","southeast",
		"south","southwest","west","northwest",
		"up","down"
	]

	$GAME_ADJ = []
	
	# Returns the reverse direction, given a direction. 
	# Adventure::reverse_direction( "north" ) #=> :south
	def Adventure::reverse_direction( direction )
		{:north=>:south, :northeast=>:southwest, :east=>:west,
			:southeast=>:northwest, :south=>:north, :southwest=>:northeast,
			:west=>:east,:northwest=>:southeast,:up=>:down,:down=>:up,
			:in=>:out,:out=>:in}[ direction.to_sym ]
	end
	
	# [Multidirection]
	# We could say "[go] north [exit] one" to choose the first north exit
	$cardinal_numbers = {
		:one=>1, :two=>2, :three=>3, :four=>4, :five=>5, 
		:six=>6, :seven=>7, :eight=>8, :nine=>9, :ten=>10,
		:eleven=>11, :twelve=>12, :thirteen=>13, :fourteen=>14, 
		:fifteen=>15, :sixteen=>16, :seventeen=>17,
		:eighteen=>18, :nineteen=>19, :twenty=>20
	}
	
	# [Multidirection]
	# We could say "[go] north first [exit] from [the] right".
	$ordinal_numbers = {
		:first=>1, :second=>2, :third=>3, :fourth=>4, :fifth=>5, 
		:sixth=>6, :seventh=>7, :eighth=>8, :ninth=>9, :tenth=>10,
		:eleventh=>11, :twelfth=>12, :thirteenth=>13, :fourteenth=>14,
		:fifteenth=>15, :sixteenth=>16, :seventeenth=>17, :eighteenth=>18,
		:nineteenth=>19, :twentieth=>20
	}
	
	$cards = {
		1=>"one", 2=>"two", 3=>"three", 4=>"four", 5=>"five", 6=>"six", 7=>"seven",
		8=>"eight", 9=>"nine", 10=>"ten", 11=>"eleven", 12=>"twelve", 13=>"thirteen",
		14=>"fourteen", 15=>"fifteen", 16=>"sixteen", 17=>"seventeen", 18=>"eighteen",
		19=>"nineteen", 20=>"twenty"
	}

	
	
	# [Multidirection]
	# If there are three choices in a line, the first is "a", the middle/center is "c",
	# and the last/rightmost is "b". If there are two choices, they are left("a") and right("b").
	$lcr = {
		:left=>"a",:middle=>"c",:center=>"c", :right=>"b", :last=>"b"
	}
	
	# [Multidirection]
	# This is called when the <from> keyword is used. There should be three
	# elements in the text array, and they should be like <offset>,from,<end>
	# where offset is 1..20 or first..twentieth or one..twenty, and end is
	# left or right or last.
	def Adventure::exit_list( text , num_choices )
		offset = 0
		position = ""
		result = -1
		if text.length == 3 && text[1] == "<from>"
			x = text[0].to_sym
			if $ordinal_numbers.key?(x)
				offset = $ordinal_numbers[x] - 1
			elsif $cardinal_numbers.key?(x) - 1
				offset = $cardinal_numbers[x]
			elsif text[0] =~ /[0-9]+/
				offset = text[0].to_i - 1
			else
				return -1
			end
			#offset = ( $ordinal_numbers[ text[0].to_sym ] ) - 1
			pos = $lcr[ text[2].to_sym ]
			a = 1; b = num_choices
			op = pos == "a" ? "+" : "-"
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
		adj = []; key = []
		text += " "
		text.gsub!(/ the | a /," ")
		text.gsub!(/^pick up|^grab/,"take")
		text.gsub!(/^quit $|^exit $|^q $/,"bye ")
		text.gsub!(/^b $/,"back ")
		text.gsub!(/^@/,"goto")
		text.gsub!(/^&/,"inspect")
		text.gsub!(/^discard/,"drop")
		text.gsub!(/^look at /,"examine ")
		text.gsub!(/ inventory /," inv ")
		# Replace occurrences of "to wwwww" with "to_wwwww"
		text.gsub!(/( to )(\w+) /) {|m| " to_" + $~[2] }
		text.gsub!(/^return /) {|m| if text[" to_inv "] then "replace " else "drop " end }
		# Replace occurrences of "in wwwww" with "in_wwwww"
		text.gsub!(/( in )(\w+) /) {|m|  " in_" + $~[2] }
		text.gsub!(/^move/,"go")
		text.gsub!(/^drink|^eat/,"consume")
		text.gsub!(/ any /) {|m| adj << $&.strip; ' '}
		text.gsub!(/^climb |^swim |^run /) {|m| adj << $&; "go " }
		text.gsub!(/^time $|^timer $/,"check timer ")
		text.gsub!(/ exit /,' ')
		text.gsub!(/^about /,"info ")
		text.gsub!(/ from /) {|m| key << $&.strip; " <from> " }
		text.strip!
		text.squeeze!(" ")
		#puts "-----> " + text.to_s.inspect
		$GAME_ADJ = adj
		return text, adj, key
	end

	
	# A random number generator
	class Die
		def Die.roll( max )
			return rand( max ) + 1
		end
	end # Die class
	
end # Adventure module
