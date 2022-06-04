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
	# > listener.vars
	# > listener.description
	class LocationListener
		include REXML::StreamListener
		
		# Create the LocationListener with the id of the room you want to load.
		def initialize( identity )
			@reading = false
			@read_description = false
			@identity = identity
			@found = false
			#@path = []
			@text = []
			@vars = {}
			@doors = {}
			@doorways = []
			# New value to hold the GDirection objects 2022-05-30 18:40:50
			@exits = {}
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
					when "direction"
						#@vars[attrs["dir"]] ||= ["*",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, "@"]
						x = GDirection.new("direction", attrs["dir"], attrs["dest"], attrs["text"] )
						x.file = attrs["file"] if attrs["file"]
						x.effect = attrs["effect"] if attrs["effect"]
						@exits[ x.directions ] = x
					when "extends"
						#@vars[attrs["dir"]] ||= ["e",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, "@"]
						x = GDirection.new("extends", attrs["dir"], attrs["dest"], attrs["text"] )
						x.file = attrs["file"] if attrs["file"]
						x.effect = attrs["effect"] if attrs["effect"]
						@exits[ x.directions ] = x
					when "doorway"
						#@vars[attrs["dir"]] ||= ["d",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s, attrs["id"]]
						# Old doorway code
						#@doors[attrs["id"].to_i] ||= [ attrs["key"].to_i, attrs["status"] ]
						# New doorway code
						x = Adventure::GDoor.new( attrs["id"].to_i )
						x.state = attrs["status"]
						@doorways << x
						x = GDirection.new("doorway", attrs["dir"], attrs["dest"], attrs["text"] )
						x.file = attrs["file"] if attrs["file"]
						x.effect = attrs["effect"] if attrs["effect"]
						x.door_id = attrs["id"].to_i
						@exits[ x.directions ] = x
					when "dropoff"
						#@vars[attrs["dir"]] ||= ["f",attrs["dest"],attrs["text"].to_s,attrs["file"].to_s,attrs["effect"].to_s]
						x = GDirection.new("dropoff", attrs["dir"], attrs["dest"], attrs["text"] )
						x.file = attrs["file"] if attrs["file"]
						x.effect = attrs["effect"] if attrs["effect"]
						@exits[ x.directions ] = x
					when "light"
						@vars["light"] ||= attrs["value"].to_i
					when "conditions"
						@vars["light"] ||= attrs["light"].to_i
						@vars["temp"] ||= attrs["temp"].to_i
						@vars["water"] ||= ( attrs["value"] == "true" )
					when "water"
						@vars["water"] ||= ( attrs["value"] == "true" )
					when "object"
						@vars["object"] ||= []
						@vars["object"] << attrs
					when "accident"
						@vars["accident"] ||= []
						@vars["accident"] << [ attrs["type"], attrs["roll"], attrs["effect"], attrs["dir"], attrs["text"] ]
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
			#return @doors
			return @doorways
		end
		
		def exits
			return @exits
		end
		
	end # LocationListener class

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

