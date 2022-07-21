# 
# ditxml.rb
# 
# dynamic xml text reader
# 
# The ditxml XML file reader defines a method of reading adventure maps from an XML file.
# It uses a streamlistener which parses through the file looking for the particular room
# that the game has requested. Once the room definition is located in the file, all the 
# relevent data is read into Ruby structures. Because the streamlistener is used, the entire
# XML file is not read into memory, and the game code can determine what data to keep and
# what to discard. 
require 'rexml/document'
require 'rexml/streamlistener'
include REXML

module Adventure
	# The LocationListener parses through an XML file looking for the specified room. 
	# You set it up by initializing the listener with a room id:
	# > listener = Adventure::LocationListener.new("ROOMID")
	# And then having the listener invoke itself:
	# > listener.do( "filename.xml" )
	# The room info can be obtained by calling:
	# > listener.vars          : contains information about the room
	# > listener.description   : contains the text that should be displayed when in the room
	# > listener.doors         : contains information about doors
	# > listener.exits         : contains information about exits from the room
	class LocationListener
		include REXML::StreamListener
		
		# Create the LocationListener with the id of the room you want to load.
		def initialize( identity )
			@reading = false
			@read_description = false
			@identity = identity
			@found = false
			@text = []
			@vars = {}
			@doors = {}
			@doorways = []
			# New value to hold the GDirection objects 2022-05-30 18:40:50
			@exits = {}
			@food = []
		end
		
		# This is a predefined method in StreamListener. It is called when an
		# opening tag is encountered, for example; <location>
		def tag_start( name, attrs )
			#@path.push( name )
			# the <location> tags should always be at the same depth, so we might 
			# be able to speed this up by checking @path.size.
			# Note: @path is not really needed and so is being removed. 
			if name == "location" && attrs["id"] == @identity
				@reading = true
				@found = true
				@vars["type"] ||= attrs["type"]
			elsif @reading
				case name
				when "description"
					@read_description = true
				when "type"
					@vars["type"] ||= attrs["value"]
				when "direction", "extends", "dropoff"
					x = GDirection.new( name, attrs["dir"], attrs["dest"], attrs["text"] )
					x.file = attrs["file"] if attrs["file"]
					x.effect = attrs["effect"] if attrs["effect"]
					@exits[ x.directions ] = x
				when "doorway"
					x = Adventure::GDoor.new( attrs["id"].to_i )
					x.state = attrs["status"]
					@doorways << x
					x = GDirection.new("doorway", attrs["dir"], attrs["dest"], attrs["text"] )
					x.file = attrs["file"] if attrs["file"]
					x.effect = attrs["effect"] if attrs["effect"]
					x.door_id = attrs["id"].to_i
					@exits[ x.directions ] = x
				when "light"
					@vars["light"] ||= attrs["value"].to_i
				when "conditions"
					@vars["light"] ||= attrs["light"].to_i
					@vars["temp"] ||= attrs["temp"].to_i
					@vars["water"] ||= ( attrs["value"] == "true" )
				# <peek> tags show us a preview of what we might see when we look into a room.
				# The information in this tag is not revealed unless we use the "look <direction>" 
				# command. If there is a monster or water or food we might be able to pick up on
				# that as well. The "peek" information is placed in a GDirection object since it 
				# can handle this information (basically, peek-ing is like go-ing in a direction
				# without the follow-through. You can't generally peek through a doorway, but maybe
				# there is a keyhole or something. If there is no <peek> tag for an exit, then 
				# there is probably nothing that can be seen. 
				# NOTE: LocationListener is not used to check the "peek" solution. That is only done
				# in the PeekListener
				#when "peek"
					#x = GDirection.new( name, attrs["dir"], attrs["dest"], attrs["text"] )
					# Water is treated as a food, but it does not grow and it never runs out. 
				when "water"
					#@vars["water"] ||= ( attrs["value"] == "true" )
					#@vars["water_ok"] ||= ( attrs["potable"] == "true" )
					x = Adventure::GFood.new( "water", attrs["quantity"], attrs["effect"], false )
					x.seen = true
					@food << x
				when "food"
					x = Adventure::GFood.new( attrs["type"], attrs["quantity"], attrs["effect"], attrs["grow"] )
					@food << x
				when "object"
					@vars["object"] ||= []
					@vars["object"] << attrs
					#puts attrs.inspect
				when "accident"
					x = GAccident.new( attrs["type"], attrs["roll"], attrs["effect"], attrs["dir"], attrs["text"] )
					x.die = attrs["die"] unless attrs["die"].nil?
					@vars["accident"] ||= []
					@vars["accident"] << x
				end
			end
		end
		
		def text( text )
			if @read_description == true
				@text = text.split("\n").map{|e| e.strip}
				@read_description = false
			end
		end
		
		# Called when an ending-tag is encountered, eg: </location>
		def tag_end( name )
			#@path.pop
			if @reading && name == "location" 
				@reading = false
			elsif @reading && name == "description"
				@read_description = false
			end
		end
		
		def do( file )
			# Add error trapping!!!
			Document.parse_stream( File.new( file ), self )
			return @found
		end
		
		def description
			return @text
		end
		
		def vars
			return @vars
		end
		
		def doors
			return @doorways
		end
		
		def exits
			return @exits
		end
		
		def food
			return @food
		end
		
	end # LocationListener class

	# > @peeker = Adventure::PeekListener.new(@location)
	# > @peeker.do(@gamefile)
	# > @peek = @peeker.peek
	class PeekListener
		include REXML::StreamListener

		def initialize( identity )
			@reading = false
			@identity = identity
			@found = false
			@peek = []
		end
		
		def tag_start( name, attrs )
			if name == "location" && attrs["id"] == @identity
				@reading = true
				@found = true
			elsif @reading
				case name
				# <peek> tags show us a preview of what we might see when we look into a room.
				# The information in this tag is not revealed unless we use the "look <direction>" 
				# command. If there is a monster or water or food we might be able to pick up on
				# that as well. The "peek" information is placed in a GDirection object since it 
				# can handle this information (basically, peek-ing is like go-ing in a direction
				# without the follow-through. You can't generally peek through a doorway, but maybe
				# there is a keyhole or something. If there is no <peek> tag for an exit, then 
				# there is probably nothing that can be seen. 
				when "peek"
					x = GDirection.new( name, attrs["dir"], attrs["dest"], attrs["text"] )
					@peek << x
				end
			end
		end

		def tag_end( name )
			@reading && name == "location" ? @reading = false : nil
		end
		
		def do( file )
			# Add error trapping!!!
			Document.parse_stream( File.new( file ), self )
			return @found
		end
		
		def peek
			return @peek
		end
		
	end # PeekListener class


	# The IntroductionListener has the sole job of pulling the game introduction from the XML
	# file. If there are more needs for this type of listener, then we'll create a generic
	# tag listener. 
	class IntroductionListener
		include REXML::StreamListener
		def tag_start( name, attrs )
			if name == "intro"
				@reading = true
			end
		end
		
		def tag_end( name )
			if name == "intro"
				@reading = false
			end
		end
		
		def text( text )
			if @reading
				@intro = text.split("\n").map{|e| e.strip}
			end
		end
		
		def do( file )
			# Add error trapping!!!
			Document.parse_stream( File.new( file ), self )
			return @intro
		end
	end # IntroductionListener class

	# The MonsterListener class is similar to the LocationListener except that it 
	# assists the various monsters in the game with their movement. There are several
	# types of monsters: stationary, patroling, and wandering. This class will help all
	# three types.
	class MonsterListener
		include REXML::StreamListener
		def initialize( identity )
			@reading = false
			@read_description = false
			@identity = identity
			@found = false
			@text = []
			@vars = {}
			@doors = {}
		end
		
		# This is a predefined method in StreamListener. It is called when an
		# opening tag is encountered, for example; <location>
		def tag_start( name, attrs )
			# the <location> tags should always be at the same depth, so we might 
			# be able to speed this up by checking @path.size.
			# Note: @path is not really needed and so is being removed. 
			if name == "location" && attrs["id"] == @identity
				@reading = true
				@found = true
				@vars["type"] ||= attrs["type"]
			elsif @reading
				case name
					when "description"
						# @read_description = true
					when "type"
						@vars["type"] ||= attrs["value"]
					when "direction"
						@vars[attrs["dir"]] ||= ["*",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, "@"]
					when "extends"
						@vars[attrs["dir"]] ||= ["e",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, "@"]
					when "doorway"
						# Monsters should only be able to go through doors when the doors are open.
						@vars[attrs["dir"]] ||= ["d",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, attrs["id"]]
						@doors[attrs["id"]] ||= [ attrs["key"], attrs["status"] ]
					when "dropoff"
						# Monsters don't fall off dropoffs. 
						# @vars[attrs["dir"]] ||= ["f",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s,attrs["effect"].to_s]
					when "light"
						# @vars["light"] ||= attrs["value"].to_i
					when "conditions"
						# @vars["light"] ||= attrs["light"].to_i
						# @vars["temp"] ||= attrs["temp"].to_i
						# @vars["water"] ||= ( attrs["value"] == "true" )
					when "water"
						# @vars["water"] ||= ( attrs["value"] == "true" )
					when "object"
						@vars["object"] ||= []
						@vars["object"] << [ attrs["id"], attrs["description"] ]
					when "accident"
						# @vars["accident"] ||= []
						# @vars["accident"] << [ attrs["type"], attrs["roll"], attrs["effect"], attrs["dir"], attrs["text"] ]
				end
			end
		end
		
		def text( text )
			# Monsters don't care
		end
		
		# Called when an ending-tag is encountered, eg: </location>
		def tag_end( name )
			if @reading && name == "location" 
				@reading = false
			# elsif @reading && name == "description"
			# 	@read_description = false
			end
		end
		
		def do( file )
			# Add error trapping!!!
			Document.parse_stream( File.new( file ), self )
			return @found
		end
		
		def description
			return ""
		end
		
		def vars
			return @vars
		end
		
		def doors
			return @doors
		end
		
	end # LocationListener class
		
end

=begin
require 'ditxml'
include REXML
listener = Adventure::LocationListener.new("F-4")
Document.parse_stream( File.new("lostcave.xml"), listener )
listener.vars
listener.description
listener.doors
=end

