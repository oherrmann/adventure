# game.rb
# 
# This is the Ruby Caves Adventure Game. 
# This version uses XML game description files.
require './ditxml'
require './game_grammar'
require './gameobjects'
require './game_container'
require './game_weapons.rb'
require './game_accidents.rb'
require './gameplayer'
require './gutils'
require './gamemonster'
require './gtime'
require './gamedirs'
require './gamedoors'
# This line required for jruby, apparently
require 'date'

module Adventure
	$version = "0.1.0"
	$understand = "I do not understand what you mean."
	ACC_TYPE = 0
	ACC_ROLL = 1
	ACC_EFFECT = 2
	ACC_FROM = 3
	ACC_TEXT = 4

	class Game
		def initialize( gamefile )
			srand
			@gamefile = gamefile if File.exists?( gamefile )
			@id,@config = Game.get_game_config()
			@id = "%0.10d" % @id
			@rooms = {}
			@doors = {}
			@location = ""
			@last_location = ""
			@game_location = ""
			@last_text = []
			@last_vars = {}
			@@messages = []
			@players = []
			@room_path = []
			@object_file = {}
			@timer = GTime.new
			@monsters = []
			@room_exits = {}
		end
		
		attr_accessor :location, :last_location, :doors
		
		# Loads the configuration file and sets the game id.
		def Game.get_game_config()
			id = 0
			config = []
			config_hash = {}
			node = 'main'
			begin
				File.open("Config.ini") do |file|
					file.each do |line|
						config << line.chomp
					end
				end
				config.each do |val| 
					if val[0] == '[' && val[-1] == ']'
						node = val[1..-2]
					else
						u,v = val.split("=")
						config_hash[ node + '/' + u ] = v
					end
				end
				# This line sorts the hash alphabetically
				config_hash = config_hash.sort_by { |key| key }.to_h
				id = config_hash["main/game.id"].to_i
				config_hash["main/game.id"] = (id + 1).to_s
				file = File.open("Config.ini","w")
				lastNode = ''
				fullKey = ''
				config_hash.each do |key,val|
					fullKey = key
					node, key = fullKey.split("/")
					if node != lastNode
						file.write( "[" + node + "]\n")
						lastNode = node
					end
					file.write( key + "=" + val + "\n" )
				end
				file.close
			rescue StandardError => err
				puts( "The configuration file could not be accessed or interpretted: " + err.message )
			end
			return id,config_hash
		end
		
		# Displays info to the user terminal.
		def Game.inform( text = "" )
			if text.class == Array
				@@messages += text
			elsif text.class == String
				@@messages << text
			end
		end
		
		def dont_understand()
			return $understand
		end
		
		# Initializes the gamefile
		def set_gamefile( gamefile )
			@rooms = {}
			@gamefile = gamefile
		end
		
		def game_intro( room = "Intro" )
			Game.inform( "Welcome to Ruby Caves Adventure Game." )
			Game.inform( "Version " + $version )
			loc = IntroductionListener.new
			Game.inform( loc.do( @gamefile ) ) if room == "Intro"
		end
		
		# Saves the room data in memory.
		def save_room( name, text, vars, exits )
			@rooms[ name.to_sym ] = [ text, vars, exits ]
		end
		
		# Deletes the room data from memory
		def kill_room( name )
			@rooms.delete( name.to_sym )
		end
		
		# Returns true if the room data is in memory
		def room_in_mem?( name )
			return ! @rooms[ name.to_sym ].nil?
		end
		
		# Retrieves the specified room data
		def get_room( name )
			@last_text, @last_vars, @room_exits = @rooms[ name.to_sym ]
		end
		
		# Return the container object for the objects in the room.
		def object_file( name )
			return @object_file[ @gamefile + "/" + name ].contents
		end
		
		# TODO: New doorway code needs to be implemented
		# Returns true if the door is locked, otherwise false.
		def door_locked?( door )
			return @doors[ door ].locked?
		end
		
		# Returns true if the door is unlocked, otherwise false.
		def door_unlocked?( door )
			return @doors[ door ].unlocked?
		end
		
		# Locks the door with the key.
		def door_lock( door, key )
			#@doors[ door ].lock( key )
			key.lock_door( @doors[door] )
		end
		
		# Unlocks the door with the key.
		def door_unlock( door, key )
			#@doors[ door].unlock( key )
			key.unlock_door( @doors[door] )
		end
		
		# Returns the id of the key needed to lock/unlock this door.
		# This code is deprecated
		def door_key( door )
			#return @doors[ door ].key
			raise "Deprecated method: door_key( door ) called!"
		end
		
		# Uploads the room from the game definition file. Returns true if the room
		# is loaded, else returns false if the room is not found.
		def upload_room( name, reset = false )
			loc = LocationListener.new( name )
			if loc.do( @gamefile )
				@last_text = loc.description
				@last_vars = loc.vars
				@room_exits = loc.exits
				# Only set door info if we haven't already read it, or if we are resetting.
				doors = loc.doors()
				doors.each do |door|
					if reset
						@doors[ door.id ] = door
					else
						@doors[ door.id ] ||= door
					end
				end
				# Create object file if it does not exist. Load objects.
				unless @object_file[ @game_location ] && not( reset )
					room = Room.new("room","room " + name )
					@object_file[ @game_location ] = room
					array = @last_vars["object"]
					objects = []
					if array
						# Each element of the array 'array', 'ele', should be a Hash of an 
						# object's attributes.
						array.each do |ele|
							# TODO: Objects should be created into their actual objects, ie, keys to 
							# GKey's, swords to GWeapons, etc.
							obj_name = ele["name"]
							obj_desc = ele["description"]
							obj_id = ele["id"]
							object = nil
							case obj_name
								when "key"
									object = GKey.new(obj_id,[],obj_description)
									doors = ele["door_list"].split(",")
									object.door_list = doors.map {|door| door.to_i }
									object.seen = ele["seen"]=="true" || false
									object.hidden = ele["hidden"]=="true" || false
									object.moveable = ele["moveable"]=="true" || true
									["id","name","description","door_list","seen","hidden","moveable"].each {|v| ele.delete(v) }
									object.mass_set_attr( ele )
								when "sword", "club", "knife", "axe", "spear"
									object = GWeapon.new( obj_id, obj_name, obj_desc )
									object.seen = ele["seen"]=="true" || false
									object.hidden = ele["hidden"]=="true" || false
									object.moveable = ele["moveable"]=="true" || true
									["id","name","description","seen","hidden","moveable"].each {|v| ele.delete(v) }
									object.mass_set_attr( ele )
								when "gun", "rifle", "machinegun", "flamethrower"
									# TODO: Not yet implemented
								else
									object = GObject.new( obj_id, obj_desc )
									object.seen = ele["seen"]=="true" || false
									object.hidden = ele["hidden"]=="true" || false
									object.moveable = ele["moveable"]=="true" || true
									["id","name","description","seen","hidden","moveable"].each {|v| ele.delete(v) }
									object.mass_set_attr( ele )
							end
							objects << object
						end
						@object_file[ @game_location ].add( objects )
					end
				end
				# We don't need the objects in the room file.
				@last_vars.delete("object")
				save_room( @game_location, @last_text, @last_vars, @room_exits )
				return true
			else
				return false
			end
		end
		
		def set_location( location )
			@location = location
			@game_location = @gamefile+"/"+location
			@room_path.push( @game_location )
			room_path_maximum = 100
			if @config["rooms/room.path.maximum"]
				room_path_maximum = @config["rooms/room.path.maximum"].to_i
			end
			if @room_path.size > room_path_maximum
				room = @room_path.shift
				unless @room_path.member?( room )
					kill_room( room )
				end
			end
		end
		
		# Play the game
		def play( name="Gwen", mode = 0, room = @config["main/start.room"] )
			#break unless @gamefile
			@mode = mode
			@playing = true
			#log( Adventure::ts(@config["main/date.format"]) + " - Game started." )
			@players[0] = GPlayer.new( name )
			@players[0].subscribe( :death ) {|p| @playing = false }
			# @players[0].take( GObject.new("torch","a torch") )
			torch = GObject.new("torch","a torch")
			torch.seen = true
			@players[0].hands.add( torch )
			o2 = GKey.new(24,[24],"a key")
			@players[0].take o2
			@rooms = {}
			@last_text = []
			@last_vars = {}
			@@messages = []
			@last_location = ""
			set_location( room )
			@input_log = []
			game_intro( room )
			while @playing          # This is the main REPL loop of the game
				update()
				input = prompt()
				interpret( input )
				other_turns()
			end
			update() if @@messages.size > 0
			#log( Adventure::ts(@config["main/date.format"]) + " - Game ended." )
		end
		
		def clear_messages
			@@messages = []
		end
		
		# The log method writes user input and game messages to a log file. 
		# User input is also stored in an internal log (last 100 inputs). 
		def log( data, flag = 0 )
			if flag == 1 && data.size > 0
				if data.class == Array
					@input_log += data
				else
					@input_log << data
				end
				while @input_log.size > 100
					@input_log.shift
				end
			end
			File.open( "logs/Log_" + @id +".log", "a" ) { |io| io.puts data }
		end
		
		# Plays the info for the current place. Also plays any data placed in 
		# the message variable.
		def update
			#puts "@location=" + @location
			#puts "@game_location=" + @game_location
			been_to = @players[0].been_to?( @location )
			if room_in_mem?( @game_location )
				get_room( @game_location )
			else
				upload_room( @location )
			end
			@players[0].in_room( @location )
			if @mode == 1
				Game.inform( "You are in room " + @location )
				Game.inform( @last_text )
			else
				if ! been_to
					Game.inform( @last_text )
				elsif @last_location != @location
					Game.inform( @last_text[0] )
				end
			end
			@players[0].last_location = @players[0].location
			check_for_accident() if ( @last_location != @location )
			if @players[0].alive? == false
				Game.inform( "You have died.")
			end
			if @playing == false
				Game.inform( "Game is over. Goodbye." )
			end
			if @last_command == "inspect" || @last_command == "check"
				puts @@messages
				#log( @@messages )
			else
				puts @@messages.wrap(70)
				#log( @@messages.wrap(70) )
			end
			@last_location = @location
			clear_messages
		end
		
		# Prompts for user input. May be timed. (timer not implemented)
		def prompt( time = 0 )
			return nil if @playing == false
			print "\n> "
			t1 = DateTime.now
			@original = gets.chomp
			# Update the timer... add up to 10 minutes for slow entries. 
			t2 = DateTime.now
			t3 = GTime.new
			t3.hms = Date.day_fraction_to_time( t2 - t1 )
			case t3.to_i/60
				when 0..10
					@timer.minutes=t3.to_i/60
				else
					@timer.minutes=10
			end
			@original, @adjectives, @keywords = Adventure::adjust_english( @original )
			#puts "adjectives = " + @adjectives.pretty
			input = @original.downcase
			case input[input.size-1,1]
				when "?"
					@punct = "?"
					input = input.delete "?"
				when "."
					@punct = "."
					input = input[0,input.size-1]
				else
					@punct="."
			end
			#log( "> " + @original, 1 )
			return "noop" if input.length == 0
			return input
		end
		
		# Interprets the user input.
		def interpret( value = "noop" )
			return nil if @playing == false
			#puts "value = " + value.to_s # TESTING
			value = value.split(" ")
			command = value.shift
			if Adventure::is_direction?( command )
				value.unshift( command )
				command = "go"
			elsif Adventure::to_direction( command )
				value.unshift( Adventure::to_direction( command ) )
				command = "go"
			elsif command == "back"
				value.unshift( command )
				command = "go"
			end
			@last_command = command
			if command.length > 0
				#puts "command = " + command.to_s # TESTING
				#puts "value = " + value.to_s # TESTING
				case command
					when "noop"
						@timer += 1.mins
					when "quit","exit","bye" then @playing = false
					when "where" then where_am_i( value )
					when "check" then query_object( value )
					when "inspect" then int_inspect( @original.split(" ")[1..-1] )
					when "go" then move( value )
					when "examine" then examine( value )
					when "look" then look_to( value )
					when "take" then take_item( value )
					when "drop" then drop_item( value )
					when "hold" then take_hold( value )
					when "unhold" then un_hold( value )
					when "consume" then consume( value )
					when "goto" then goto_room( @original.split(" ")[1..-1] )
					when "pinfo" then programmer_info( value )
					when "reload" then reload_room( @original.split(" ")[1..-1], false )
					when "reset" then reload_room( @original.split(" ")[1..-1], true )
					else
						Game.inform( dont_understand() )
				end
			end
		end
		
		# The other_turns method services other 'players' in the game, such as monsters.
		def other_turns()
			@monsters.each do |monster|
				monster.play
			end
		end
		
		def where_am_i( text )
			Game.inform( @last_text )
		end
		
		def programmer_info( text )
			puts "location = " + @game_location
			puts "time = " + @timer.out()
		end
		
		# The take command attempts to pick up objects in a room.
		def take_item( text )
			objects = @object_file[ @gamefile + "/" + @location ]
			@object_file[ @gamefile + "/" + @location ].take_from( text[0], @players[0].inventory )
		end
		
		# The drop command attempts to discard objects in a room.
		def drop_item( text )
			if @players[0].hands.contains?( text[0] ) > 0
				@players[0].hands.take_from( text[0], @object_file[ @gamefile + "/" + @location ] )
			else
				@players[0].inventory.take_from( text[0], @object_file[ @gamefile + "/" + @location ] )
			end
		end
		
		# The take_hold method allows the player to take something out of their inventory
		# and hold it in their hands. First it places any item already in hand into inventory.
		# If no item matches the request, then the item that was placed in inventory is  moved
		# back to the hands. 
		def take_hold( text )
			un_hold()
			@players[0].inventory.take_from( text[0], @players[0].hands )
			if @players[0].hands.size == 0 && @players[0].last_handled
				@players[0].inventory.drop( @players[0].last_handled )
				@players[0].hands.add( @players[0].last_handled )
				@players[0].last_handled = nil
			end
		end
		
		# Player can only hold 1 item in hands, so this returns it to inventory if the 
		# player wishes to have hands free.
		def un_hold( text = [] )
			@players[0].hands.each do |obj|
				@players[0].last_handled = obj
				@players[0].hands.drop( obj )
				@players[0].inventory.add( obj )
				if @last_command == "unhold"
					Game.inform( obj.description.to_s + " was replaced in inventory. ")
				end
			end
		end
		
		# Attempts to move the player in a direction
		def move( text )
			direction = text.shift()
			counter = 0
			back = false
			back_direction = []
			exits = count_exits( direction )
			if exits == 0 && direction != 'back'
				Game.inform("There are no exits in that direction.")
				return
			elsif @room_exits[ [direction, counter ] ] && text.length == 0
				# example: > go north
				# do nothing... we are on-track
			elsif direction == 'back'
				# example: > back
				back = true
				direction = @players[0].go_back?().to_s
				back_room = @players[0].go_back_room.to_s # 06/05/22
				# Find the back direction that leads to the desired destination.
				@room_exits.each_pair do
					|k,v|
					if v.destination == back_room then back_direction = v.directions end
				end
				direction, counter = back_direction
			elsif exits > 1 && text.length == 0
				Game.inform("You need to specify which exit to take.")
				return
			elsif text[0] =~ /^[0-9]+$/
				# example: > go north 1
				counter = text[0].to_i
			elsif exits == 2 && text.length == 1 && ['a','b'].include?($lcr[text[0].to_sym])
				# example: > go north right
				counter = $lcr[text[0].to_sym] == 'a' ? 1 : 2
			elsif exits == 3 && text.length == 1 &&  ['a','b','c'].include?($lcr[text[0].to_sym])
				# example: > go north middle
				case $lcr[text[0].to_sym]
					when 'a' then counter = 1
					when 'b' then counter = 3
					when 'c' then counter = 2
				end
			elsif @keywords.include?("from")
				# example: > go north second from left
				counter = Adventure::exit_list( text, exits )
			elsif not( text[0].nil? ) && $ordinal_numbers.key?( text[0].to_sym)
				# example: > go north first
				counter = $ordinal_numbers[text[0].to_sym]
			elsif not( text[0].nil? ) && $cardinal_numbers.key?( text[0].to_sym)
				# example: > go north one
				counter = $cardinal_numbers[text[0].to_sym]
			else
				Game.inform( dont_understand )
				return
			end
			direction = [direction, counter]
			loc = @room_exits[ direction ]
			# check if there is a door
			if loc && loc.type == "doorway"
				door = loc.door_id.to_i
				keys = @players[0].inventory.select {|obj| obj.class <= Adventure::GKey && obj.key_works?(door) }
				key = keys.size
				# TODO: Select one of the keys? For now choose the first one that comes up.
				item = keys[0]
				if door_locked?( door ) && key < 1
					Game.inform( "The door is locked." )
					direction[0] = "locked" # Setting the direction to 'locked' disables the move.
					@timer += 2.mins
				elsif door_locked?( door ) && key > 0
					door_unlock( door, item )
					Game.inform( "The door is locked but you have the key, and unlock it.")
					@timer += 1.mins
				elsif door_unlocked?( door )
					Game.inform( "The door is unlocked so you are able to pass through." )
					@timer += 30.secs
				end
			end
			# Try to go in the direction requested. refresh the loc local
			loc = @room_exits[ direction ]
			if direction
				if loc
					@players[0].last_direction = direction[0]
					if loc.file.size > 0
						set_gamefile( loc.file )
					end
					set_location( loc.destination )
					Game.inform( loc.text ) if loc.text.length > 0
					@players[0].go( direction[0], loc.destination, counter, back )
					@players[0].adjust( loc.effect ) if loc.effect.length > 0
					#@playing = false if @players[0].alive? == false
					if loc.type == "extends"
						@timer += 30.secs
					else
						@timer += 1.mins
					end
				else
					Game.inform( "You cannot go that way.")
					@timer += 1.mins
				end
			else
				Game.inform( dont_understand() )
			end
			@players[0].adjust( "ene-0.5" )
		end

		# Attempts to move the player in a direction
		def old_move( text )
			direction = text[0]
			# adjust for 'back' command
			back = false
			if direction == "back"
				direction = @players[0].go_back?().to_s
				back = true
			end
			# check if there is a door
			if @last_vars[ direction ] && @last_vars[ direction ][LOC_TYPE] == GO_DOORWAY
				door = @last_vars[ direction ][LOC_DOOR]
				key = @players[0].inventory.contains?("key",{"key"=>door_key( door )})
				if door_locked?( door ) && key < 1
					Game.inform( "The door is locked." )
					direction = "locked" # Setting the direction to 'locked' disables the move.
					@timer += 2.mins
				elsif door_locked?( door ) && key > 0
					door_unlock( door, door_key( door ) )
					Game.inform( "The door is locked but you have the key, and unlock it.")
					@timer += 1.mins
				elsif door_unlocked?( door )
					Game.inform( "The door is unlocked so you are able to pass through." )
					@timer += 30.secs
				end
			end
			# Try to go in the direction requested.
			counter = 0
			if direction
				if @last_vars[ direction ]
					loc = @last_vars[ direction ]
					@players[0].last_direction = direction
					if loc[LOC_FILE].size > 0
						set_gamefile( loc[LOC_FILE] )
					end
					set_location( loc[LOC_DEST] )
					Game.inform( loc[LOC_TEXT] ) if loc[LOC_TEXT]
					@players[0].go( text[0], back )
					@players[0].adjust( loc[LOC_EFFECT] ) if loc[LOC_TYPE] == GO_DROPOFF
					#@playing = false if @players[0].alive? == false
					if loc[LOC_TYPE] == GO_EXTENDS
						@timer += 30.secs
					else
						@timer += 1.mins
					end
				else
					Game.inform( "You cannot go that way.")
					@timer += 1.mins
				end
			else
				Game.inform( dont_understand() )
			end
			@players[0].adjust( "ene-0.5" )
		end

		
		# This routine checks to see if an accident should occur.
		def check_for_accident
			return unless @last_vars["accident"] 
			accident = [] # <--The list of accidents that actually occur
			@last_vars["accident"].each do |acc|
				next if acc.source && acc.source != @players[0].last_direction
				accident << acc if Die.roll( acc.die.nil? ? 20 : acc.die ) < acc.roll.to_i
			end
			if accident.size > 0
				# The accident(s) has/have occurred! 
				accident.each do |acc|
					Game.inform( "Warning: an accident has occured: " + acc.type )
					Game.inform( acc.text ) unless acc.text.empty?
					@players[0].adjust( acc.effect )
				end
			end
		end
		
		# ***Not yet implemented***
		# #examine allows detailed looking at specific objects.
		def examine( text )
		end
		
		# 'look_to' is the basic handler for 'look' commands. There are two modes; 'look <direction>'
		# and 'look around', which looks in all directions. Eventually, 'look <direction>' should cause
		# the interpretter to give more detailed analysis than the more general 'look around'. Also,
		# It should be noted that 'look around' does not look up or down.
		def look_to( value )
			if value[0] == "around" || value == []
				find_hidden = false
				vars = @last_vars
				# Check if there is light enough to see
				tl = @players[0].hands.contains?("torch") + @players[0].inventory.contains?("torch")
				al = @last_vars["light"].to_i
				al += 10 if tl > 0
				ch = Die.roll( 20 )
				if al >= 5 && al < 10 && ch > 10
					Game.inform("You are not able to see anything here.")
					return
				elsif al < 5
					Game.inform("It is too dark for you to see anything.")
					return
				end
				# Check for adjacent rooms ( direction tags )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					#rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DIRECTION )
					rooms << dir if ( look( [dir] )[0] == 1 && count_exits(dir, "direction") > 0 )
				end
				roomss = rooms.size
				if roomss > 0 then rooms = Adventure::list_to_english( rooms ) end
				if roomss == 1
					Game.inform( "There is an exit to the " + rooms + "." )
				elsif roomss > 1 
					Game.inform( "There are exits to the " + rooms + "." )
				end
				# Check for extended room ( extends tag )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					#rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_EXTENDS )
					rooms << dir if ( look( [dir] )[0] == 1 && count_exits(dir, "extends") > 0 )
				end
				roomss = rooms.size
				if roomss == 8
					Game.inform( "The room extends in all directions." )
				elsif roomss > 0 
					rooms = Adventure::list_to_english( rooms )
					Game.inform( "The room extends to the " + rooms + "." )
				end
				# Check for doors ( doorway tags )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					#rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DOORWAY )
					rooms << dir if ( look( [dir] )[0] == 1 && count_exits(dir, "doorway") > 0 )
				end
				roomss = rooms.size
				if roomss > 0 then rooms = Adventure::list_to_english( rooms ) end
				if roomss == 1
					Game.inform( "There is a door to the " + rooms + "." )
				elsif roomss > 1 
					Game.inform( "There are doors to the " + rooms + "." )
				end
				#Check for dropoffs ( dropoff tag )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					#rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DROPOFF )
					rooms << dir if ( look( [dir] )[0] == 1 && count_exits(dir, "dropoff") > 0 )
				end
				roomss = rooms.size
				if roomss > 0 then rooms = Adventure::list_to_english( rooms ) end
				if roomss == 1
					Game.inform( "There is a dropoff to the " + rooms + "." )
				elsif roomss > 1 
					Game.inform( "There are dropoffs to the " + rooms + "." )
				end
				# number of times looked around
				@rooms[@game_location.to_sym][1][:looked] ||= 0
				@rooms[@game_location.to_sym][1][:looked] += 1
				if ( Die.roll(6) - 1 ) < @rooms[@game_location.to_sym][1][:looked]
					find_hidden = true
				end
				# check for objects
				if object_file( @location ).length > 0
					object_file( @location ).each { |object|
						if object.hidden != true || find_hidden == true
							object.seen = true
							# Only find one hidden object at a time
							if object.hidden == true
								object.hidden = false
								find_hidden = false
							end
						end
					}
					# TODO: how to find hidden items?
					Game.inform( "The following objects can be seen: " + list_objects( object_file( @location ) ) )
				end
			else
			 Game.inform( look( value, true )[1] )
			end
		end
		
		def list_objects( list, hidden = false )
			if list.class == Array # Assumed an array of gobjects???
				return list.map { |e| e.description }.join( ", ")
			elsif list.class == String
				return list.split(",").map { |e| "a " + e }.join( ", ")
			elsif list.class == Container
				return list.all_items(hidden).join( ", " )
			end
		end
		
		# look allows the player to look in a particular direction. If the ambient light level
		# is less than 5 then you cannot see. If it is less than 10 you might not see. Having a
		# torch might improve your chances. look() is called by look_to().
		def look( text, rem = false )
			text[0] = Adventure::to_direction( text[0] ) if Adventure::to_direction( text[0] )
			dir = text[0] if ( text && Adventure::is_direction?( text[0] ) )
			result = [-1,""]
			if dir == "up"
				dir_show = "above you"
			elsif dir == "down"
				dir_show = "below you"
			else
				dir_show = "to the " + text[0]
			end
			if dir
				# Only include the "looked" count if the player looked specifically in that 
				# direction. Otherwise, the look count for each direction would increase by 4
				# every time the player 'looked around'
				if rem
					# Symbol#+ is defined in gutils.rb
					rem_looked = :looked + dir
					@rooms[@game_location.to_sym][1][rem_looked] ||= 0
					@rooms[@game_location.to_sym][1][rem_looked] += 1
				end
				tl = @players[0].hands.contains?("torch") + @players[0].inventory.contains?("torch")
				al = @last_vars["light"].to_i
				al += 10 if tl > 0
				ch = Die.roll( 20 )
				ex = []
				# Return immediately if you cannot see anything
				if ( al >= 5 && al < 10 && ch > 10 )
					result[0] = 0
					result[1] = "You are not able to see anything #{dir_show}. "
					@timer += 5.secs
					return result
				end
				if al < 5
					result[0] = 0
					result[1] = "It is too dark for you to see anything. "
					@timer += 5.secs
					return result
				end
				# Check the exit types in each direction
				["direction", "extends", "doorway", "dropoff"].each do |d|
					ex << count_exits(dir, d )
				end
				if ex[0] == 1
					result[0] = 1
					result[1] += "There is an exit #{dir_show}. "
				elsif ex[0] > 1
					result[0] = 1
					result[1] += "There are #{ex[0]} exits #{dir_show}. "
				end
				if ex[1] > 0 
					result[0] = 1
					result[1] += "The room extends #{dir_show}. "
				end
				if ex[2] == 1 
					result[0] = 1
					result[1] += "There is a door #{dir_show}. "
				elsif ex[2] > 1
					result[0] = 1
					result[1] += "There are #{ex[2]} doors #{dir_show}. "
				end
				if ex[3] > 0 
					result[0] = 1
					result[1] += "There is a dropoff #{dir_show}. "
				end
				if result[0] < 0 
					result[0] = 0
					result[1] = "There is nothing of interest to see #{dir_show}. "
				end
			else
				result = [-1,"Look where?"]
			end
			@timer += 5.secs
			return result
		end
		
		# #count_exits determines the number of exits of a type that are in a 
		# certain direction. replaces code like:
		#     @last_vars[ dir ][LOC_TYPE]==GO_XXX
		def count_exits(dir, type="")
			result = 0
			@room_exits.each_pair do |key,val|
				direction, counter = key
				if direction == dir && ( val.type == type || type.empty? ) then result += 1 end
			end
			return result
		end
		
		# Attempts to describe an object; "what --- "
		def query_object( text )
			if text.member? "status"
				text = ["status"]
			elsif text.member? "path"
				text = ["path"]
			elsif text.member? "objects"
				text = ["objects"]
			end
			case text[0]
				when "room"
					Game.inform( "The name of this room is #{@location}." )
				when "rooms"
					Game.inform( "Rooms visited:" )
					Game.inform( @room_path.map { |e| e+", "} )
				when "status"
					Game.inform( @players[0].status )
				when "path"
					Game.inform( @players[0].path.path().join(", ") )
					Game.inform( "pointer=" + @players[0].path.pointer().to_s )
				when "objects"
					Game.inform( @object_file.inspect )
				when "inventory"
					if @players[0].inventory.size + @players[0].hands.size == 0
						Game.inform("Your inventory is empty.")
					elsif @players[0].inventory.size == 0
					else
						Game.inform("Your inventory includes " + @players[0].inventory.all_items().join(", ") )
					end
					if @players[0].hands.size > 0
						Game.inform("You are holding " + @players[0].hands.all_items().join(", ") )
					end
				when "timer"
					timer,res = @timer.dhms, []
					if timer[0] == 1 then res << "1 day" end
					if timer[0] > 1 then res << "%d days" % timer[0] end
					if timer[1] == 1 then res << "1 hour" end
					if timer[1] > 1 then res << "%d hours" % timer[1] end
					if timer[2] == 1 then res << "1 minute" end
					if timer[2] > 1 then res << "%d minutes" % timer[2] end
					if res.size == 0 then res << "0 minutes" end
					Game.inform( "Game time = #{res.join(", ")}." )
				else
					Game.inform( dont_understand() )
			end
			@timer += 5.secs
		end
		
		# The consume method allows the player to consume food and water in order to 
		# regain energy and heal.
		def consume( text )
			
			if text.member?( "water" )
				@players[0].adjust( "ene+20;str+1" )
				Game.inform( "Ahhhh! The pause that refreshes. ")
				e = @players[0].energy()
				Game.inform( "Your current energy level is " + e.to_s )
			elsif text.member?( "food" )
				@players[0].adjust( "ene+50;str+2" )
				Game.inform( "Very tasty! ")
				e = @players[0].energy()
				Game.inform( "Your current energy level is " + e.to_s )
			end
		end
		
		# The int_inspect method implements the game's inspect command, which is a developer
		# command that allows the programmer to view the internal state of the game while it
		# is playing. The inspect command may also be abbreviated to '&'.
		def int_inspect( text )
			text = text.join(" ")
			if @config["prog/command.inspect"] == "yes"
				begin
					Game.inform( deval{text} )
				rescue Exception => e
					puts "Inspect Fail!: " + e.class.name + ": " + e.message + "\n"
					puts "Call Backtrace:"
					e.backtrace.each {|line| 
						line = line.to_s 
						puts "  " + line.to_s[line.to_s.rindex("/")...line.to_s.size] 
					}
				end
			else
				Game.inform( dont_understand() )
			end
		end
		
		# The goto_room method implements the game's goto command, which is a developer
		# command that allows the programmer to jump from his current location to any
		# other location in the game. The goto command may be called as 'goto <room>' to
		# go to any room in the current file, or 'goto <file>/<room>' to go to any room 
		# in the game, including those in other files. 
		def goto_room( text )
			room = text[0]
			if @config["prog/command.goto"] == "yes"
				if room["/"]
					room = room.split("/")[1]
					set_gamefile( text[0].split("/")[0] )
				end
				if upload_room( room )
					@players[0].path.clear()
					set_location( room )
				else
					Game.inform( "That room cannot be found." )
				end
			else
				Game.inform( "I cannot execute that command in player mode." )
			end
		end
		
		# The reload_room method allows the developer to reload a room during testing.
		def reload_room( text, reset = false )
			if text[0]
				if upload_room( text[0], reset)
					Game.inform( "Room #{text[0]} has been re-loaded." )
				else
					Game.inform( "Room #{text[0]} could not be found in #{@gamefile}." )
				end
			end
		end
		
		
		def to_s()
			return "<#Ruby Caves Adventure Game!>"
		end
		
		def inspect
			return ""
		end
		
	end #Game class
	
	
end # Adventure module
