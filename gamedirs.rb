# gamedirections.rb
# 
# example:
# 	<direction dir="north-1" dest="X1" text="You are on stairs leading up." file="lostcave.xml" />
# 
# x = GDirection.new("direction","north-1","X1","You are on stairs leading up")
# x.file = "lostcave.xml"
# x.effect = "experience+5"
# x.door_id = ""
# 
module Adventure
	class GDirection
		def initialize( type, direction, destination, text="" )
			@type = type
			@counter = 0
			if direction["-"]
				@counter = direction[direction.index("-")+1...direction.size].to_i
				direction = direction[0...direction.index("-")]
			end
			@direction = direction
			@destination = destination
			@text = text
			@file = ""
			@effect = ""
			# A door_id is stored in the GDirection, but nothing else about the door itself,
			# to ensure encapsulation of data.
			@door_id = ""
		end
				
		attr_accessor :type, :destination, :text, :file, :effect, :door_id
		attr_reader :counter, :direction
		
		# Get the value of the direction and the counter together in the form "<direction>-<counter>"
		def direction_sub
			sub = ""
			if @counter > 0
				sub = "-" + @counter.to_s
			end
			return @direction + sub
		end
		
		# Return an Array of the direction and the counter together
		def directions
			return [ self.direction, self.counter ]
		end
		
		# Set the direction. If the counter is not specified then the counter = 0. It is up to the locus to 
		# make sure that the counters make sense.
		def direction=(value)
			cntr = 0
			if value["-"]
				cntr = value[value.index("-")+1...value.size].to_i
				value = value[0...value.index("-")]
			end
			unless $directions_all.member? value then return nil end
			unless cntr > 0 && $directions.member?(value) then return nil end
			@direction = value
			@counter = cntr
			return self
		end
		
		# Pretty-print the GDirection object
		def pretty(level=0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = "\n" + indent + "<" + self.class.name + ":" + self.object_id.to_s
			result += "\n" + indent2 + "@type:" + @type
			result += "\n" + indent2 + "@direction:" + @direction
			result += "-" + @counter.to_s if @counter > 0
			result += "\n" + indent2 + "@destination:" + @destination
			result += "\n" + indent2 + "@file:" + @file unless @file.empty?
			result += "\n" + indent2 + "@effect:" + @effect unless @effect.empty?
			result += "\n" + indent2 + "@text:" + @text unless @text.empty?
			result += "\n" + indent2 + "@door_id:" + @door_id.to_s if @door_id
			result += "\n" + indent + ">"
			return result
		end
		
		# Convert the GDirection object to an XML tag
		def to_xml
			result = "<" + @type + " " + "dir=\"" + @direction
			if @counter > 0 then result += "-" + @counter.to_s end
			result += "\" dest=\"" + @destination + "\" "
			unless @text.empty? then result += "text=\"" + @text + "\" " end
			unless @file.empty? then result += "file=\"" + @file + "\" " end
			unless @effect.empty? then result += "effect=\"" + @effect + "\" " end
			unless @door_id.empty? then result += "id=\"" + @door_id + "\" " end
			result += "/>"
			return result
		end
		
		# Generate a GDirection object from an XML directional tag
		def GDirection.from_xml( text )
			attr = Hash.new("")
			text = text[1...-3]
			type = text[0...text.index(" ")]
			if not ["direction","extends","doorway","dropoff"].member?(type) then return nil end
			text = text[text.index(" ")+1...text.size]
			# from here, load all the quoted attributes
			while text do
				name = text[0...text.index("\"")-1]
				value = text[text.index("\"")+1...text.index("\"",text.index("\"")+1)]
				text = text[text.index("\"",text.index("\"")+1)+2...text.size]
				attr[name.to_sym] = value
			end
			result = GDirection.new(type, attr[:dir], attr[:dest], attr[:text])
			result.file = attr[:file] unless attr[:file].empty?
			result.effect = attr[:effect] unless attr[:effect].empty?
			result.door_id = attr[:id] unless attr[:id].empty?
			return result
		end
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
	end # GDirection class
end # Adventure module
