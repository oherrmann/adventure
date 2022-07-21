# game.rb
# 
# $LOAD_PATH.unshift((`cd`).gsub("\\","/").chomp)
# 
# This is the Ruby Caves Adventure Game. 
# This version uses XML game description files.
require 'stringio'
require 'securerandom'
require './ditxml'
require './game_grammar'
require './gameobjects'
require './game_container'
require './game_weapons'
require './game_accidents'
require './gameplayer'
require './gutils'
require './gamemonster'
require './gtime'
require './gamedirs'
require './gamedoors'
require './game_food'
require './game_loadsave'

# TODO: when 'taking' food, if you already have that food, it should add it to the same
# food object. When food is 'dropped' onto the floor, it is lost. This goes for water as well.
# TODO: You cannot have more than 10 units of food and 10 units of water in your inventory.
# TODO: during a fight or a fall, your canteen may break. If that happens you will lose
# all of your water, and you will have to find a new canteen to carry more. 
# TODO: In a fight or accident, you may also lose food. 
# TODO: If you eat when you are not hungry or drink when you are not thirsty, you will experience
# negative effects. 

module Adventure
	$version = "0.1.0"
	$understand = "I do not understand what you mean."

	class Game
		def initialize( gamefile )
			srand
			@timer = GTime.new
			@mode = 0
			@gamefile = gamefile if File.exists?( gamefile )
			@id,@config = Game.get_game_config()
			@id = "%0.10d" % @id
			@location = ""
			@last_location = ""
			@game_location = ""
			@players = []             # persistent
			@object_file = {}         # persistent
			@doors = {}               # persistent
			@food={}                  # persistent
			@monsters = []            # persistent
			@rooms = {}               # transient
			@last_text = []           # transient; -- stored in @rooms
			@last_vars = {}           # transient; -- stored in @rooms
			@room_exits = {}          # transient; -- stored in @rooms
			@room_path = []           # transient; sort of an index for @rooms
			@@messages = []
			@moves = 0
		end
		
		attr_accessor :location, :last_location, :doors, :timer
		attr_reader :mode
		
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
			if Array === text
				@@messages += text
			elsif String === text
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

		def room_exists?( name )
			return true if room_in_mem?( name )
			loc = LocationListener.new( name )
			return loc.do( @gamefile )
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
				# Only set food info if we haven't already read it, or if we are resetting.
				# Only set it up if there is actually food in the room. 
				unless @food.key?(@game_location) && not( reset )
					if loc.food.length > 0
						@food[ @game_location ] = Room.new("room food","food in room " + name )
						loc.food.each do |nom|
							@food[ @game_location ].add( nom )
						end
					end
				end
				# Create object file if it does not exist. Load objects.
				unless @object_file.key?(@game_location) && not( reset )
					@object_file[ @game_location ] = Room.new("room","objects in room " + name )
					array = @last_vars["object"]
					objects = []
					if array
						# Each element of the array 'array', 'ele', should be a Hash of an 
						# object's attributes.
						array.each do |ele|
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
								object.effect = ele["effect"] || ""
								object.hidden_text = ele["hidden_text"] || ""
								["id","name","description","seen","hidden","moveable",
									"effect","hidden_text"].each {|v| ele.delete(v) }
								object.mass_set_attr( ele )
							when "gun", "rifle", "machinegun", "flamethrower"
								# TODO: Not yet implemented: GRangeWeapon
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

		# Return the container object for the objects in the room.
		def object_file( name )
			return @object_file[ @gamefile + "/" + name ].contents
		end
		
		# Return the container object for the food in the room
		def food_file( name )
			if @food[ @gamefile + "/" + name ]
				return @food[ @gamefile + "/" + name ].contents
			end
			return nil
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
			room ||= "Intro"
			@playing = true
			#log( Adventure::ts(@config["main/date.format"]) + " - Game started." )
			@players[0] = GPlayer.new( name )
			@players[0].subscribe( :death ) {|p| @playing = false }
			obj = GObject.new("torch","a torch")
			obj.seen = true
			@players[0].hands.add( obj )
			obj = GObject.new("canteen","a canteen")
			obj.seen = true
			@players[0].take( obj )
			obj = GKey.new(24,[24],"a key")
			@players[0].take( obj )
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
		rescue Exception => error
			error_message( "Error!", error )
			@playing = false
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
			if not( been_to )
				Game.inform( @last_text )
				Game.inform( hidden_clues( @location ) )
			elsif @last_location != @location
				Game.inform( @last_text[0] )
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
			print "\nRCA> "
			t1 = Time.now
			@original = gets.chomp
			# Update the timer... add up to 10 minutes for slow entries. 
			t2 = Time.now
			t3 = GTime.new
			t3.dhms = GTime.day_fraction_to_time( t2 - t1 )
			#puts t3.dhms.inspect
			case t3.to_i
			when 0..600
					@timer.seconds=t3.to_i
			else
					@timer.minutes=10
			end
			input, @adjectives, @keywords = Adventure::adjust_english( @original.downcase )
			case input[input.size-1,1]
				when "?"
					@punct = "?"
					input.delete! "?"
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
		
		# Interprets the user input. check 
		def interpret( value = "noop" )
			return nil if @playing == false
			value = value.split(" ")                  # 'value' is an array from here on
			command = value.shift
			if Adventure::is_direction?( command )    # 'command' is 'north', 'south', etc
				value.unshift( command )
				command = "go"
			elsif Adventure::to_direction( command )	# 'command' is 'n', 's', etc
				value.unshift( Adventure::to_direction( command ) )
				command = "go"
			elsif command == "back"                   # 'command' is 'back'
				value.unshift( "back" )
				command = "go"
			elsif command == "stats" || command == "status"
				value = ["status"]
				command = "check"
			elsif value.include?("stats")
				value.map! {|ele| ele=="stats" ? "status" : ele }
			elsif ["inventory","inv"].include?(command)
				value = ["inv"]
				command = "check"
			end
			@last_command = command
			if command.length > 0
				#puts "command = " + command.to_s # TESTING
				#puts "value = " + value.to_s # TESTING
				case command
					when "noop"
						@timer += 1.mins
					when "info" then about_the_game( value )
					when "bye" then @playing = false
					when "where" then where_am_i( value )
					when "check" then query_object( value )
					when "inspect" then int_inspect( @original.split(" ")[1..-1] )
					when "go" then move( value )
					when "examine" then examine( value )
					when "look" then look_to( value )
					when "take" then take_item( value )
					when "drop" then drop_item( value )
					when "hold" then take_hold( value )
					when "replace" then replace( value )
					when "sleep" then sleep( value )
					when "consume" then consume( value )
					when "goto" then goto_room( @original.split(" ")[1..-1] )
					when "pinfo" then programmer_info( value )
					when "reload" then reload_room( @original.split(" ")[1..-1], false )
					when "reset" then reload_room( @original.split(" ")[1..-1], true )
					when "save" then save_game_file( @original.split(" ")[1..-1].join(" ") )
					when "load" then load_game_file( @original.split(" ")[1..-1].join(" ") )
					else
						Game.inform( dont_understand() )
				end
			end
		end
		
		# This method checks for hidden objects in the room, and if there are
		# any, and they have clues, it adds them to the messages for the player.
		# Called in update(), where_am_i(), and look_to
		def hidden_clues( name )
			return object_file( name ).select {|obj| obj.hidden == true && 
				obj.respond_to?(:hidden_text) && obj.hidden_text.length > 0}.map {|obj| 
					obj.hidden_text }
		end
		
		def about_the_game( text )
			if text == []
				puts "--------------------------------------------"
				puts "Ruby Caves Adventure Game"
				puts "Version " + $version
				puts "(c)2011, 2022 by KittySoft Solutions"
				puts "Programmer Gwen Morgan"
				puts "--------------------------------------------"
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
			Game.inform( hidden_clues( @location ) )
		end
		
		def programmer_info( text )
			puts "location = " + @game_location
			puts "    time = " + @timer.out()
			puts "      id = " + @id
		end
		
		# The take command attempts to pick up objects in a room.
		def take_item( text )
			# Quantity is generally just for food for now
			qty, text = first_word_qty( text )
			success = [false, ""]
			if @object_file[ @game_location ].contains?( text[0] ) > 0
				success = @object_file[ @game_location ].take_from( text[0], qty, @players[0].inventory )
			elsif @food[ @game_location ].not_nil? && @food[ @game_location ].contains?( text[0] ) > 0
				success = @food[ @game_location ].take_from( text[0], qty, @players[0].inventory )
			else
				Game.inform( "That item cannot be found here. " )
				return
			end
			Game.inform( success[1] )
		end
		
		# The drop command attempts to discard objects in a room.
		def drop_item( text )
			qty, text = first_word_qty( text )
			success = [false, ""]
			if @players[0].hands.contains?( text[0] ) > 0
				success = @players[0].hands.take_from( text[0], qty, @object_file[ @gamefile + "/" + @location ] )
				Game.inform( success[1] )
			else
				success = @players[0].inventory.take_from( text[0], qty, @object_file[ @gamefile + "/" + @location ] )
				Game.inform( success[1] )
			end
		end
		
		def first_word_qty( text )
			qty = 1
			if text[0] =~ /[0-9]+/
				qty = text[0].to_i
				text.shift
			elsif $cardinal_numbers.key?( text[0].to_sym )
				qty = $cardinal_numbers[ text[0].to_sym ]
				text.shift
			end
			return qty, text
		end
		
		# The take_hold method allows the player to take something out of their inventory
		# and hold it in their hands. First it places any item already in hand into inventory.
		# If no item matches the request, then the item that was placed in inventory is  moved
		# back to the hands. 
		def take_hold( text )
			replace()
			success = @players[0].inventory.take_from( text[0], 1, @players[0].hands )
			Game.inform( success[1] )
			if success[0] == false && not( @players[0].last_handled.nil? )
				@players[0].inventory.drop( @players[0].last_handled )
				@players[0].hands.add( @players[0].last_handled )
				@players[0].last_handled = nil
			end
		end
		
		# Player can only hold 1 item in hands, so this returns it to inventory if the 
		# player wishes to have hands free.
		def replace( text = [] )
			@players[0].hands.each do |obj|
				@players[0].last_handled = obj
				@players[0].hands.drop( obj )
				@players[0].inventory.add( obj )
				if @last_command == "replace"
					Game.inform( obj.description.to_s + " was replaced in inventory. ")
				end
			end
		end
		
		def sleep( text )
			sleep = @players[0].sleep( text, @timer )
			#puts sleep.pretty
			if sleep
				@timer += sleep
				Game.inform("You slept " + sleep.hrs.to_s + " hours. ")
				Game.inform("You may sleep again after " + @players[0].next_sleep.out + ". ")
			else
				Game.inform("Too early to sleep. You may sleep again after ")
				Game.inform(@players[0].next_sleep.out + ". ")
			end
		end
		
		# Attempts to move the player in a direction
		def move( text )
			# TODO: If there is only one exit out of a room, 'out' should 
			# be able to work for that exit. 
			direction = text.shift()
			counter = 0
			back = false
			back_direction = []
			exits = count_exits( direction )
			if exits == 0 && ( direction != 'back' && direction != 'out' ) 
				Game.inform("There are no exits in that direction.")
				@timer += 1.mins
				return
			elsif @room_exits[ [direction, counter ] ] && text.length == 0
				# example: > go north
				# do nothing... we are on-track
			elsif direction == 'back' || direction == 'out'
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
				@timer += 1.mins
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
				@timer += 2.mins
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
					@moves += 1
					unless loc.text.empty? then Game.inform( loc.text ) end
					@players[0].go( direction[0], loc.destination, counter, back )
					unless loc.effect.empty? then @players[0].adjust( self, loc.effect ) end
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
				@timer += 2.mins
			end
			@players[0].adjust( self, "ene-1" )
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
					Game.inform( "Warning: an accident has occurred: " + acc.type )
					Game.inform( acc.text ) unless acc.text.empty?
					@players[0].adjust( self, acc.effect )
				end
			end
		end
		
		# ***Not yet implemented***
		# #examine allows detailed looking at specific objects.
		# eg; look at mushrooms in room
		# examine sword
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
				# Check for food and water. 
				if food_file( @location ).not_nil?
					f = w = 0
					food_file( @location ).each do |object|
						object.seen = true
						object.type == "water" ? w += 1 : f += 1
					end
					if f > 0
						Game.inform("The following food items can be seen: ")
						Game.inform( list_objects( food_file( @location ) ) + ".")
					end
					if w > 0
						Game.inform("There is water at this location.")
					end
				end
				# check for objects. Maybe find hidden objects. Non-hidden objects 
				# should all become 'seen' after #look_to is executed.
				find_hidden = true if ( Die.roll(6) - 1 ) < @rooms[@game_location.to_sym][1][:looked]
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
					x = list_objects( object_file( @location ) )
					if x.length > 0
						Game.inform( "The following objects can be seen: ")
						Game.inform( x )
					end
					Game.inform( hidden_clues( @location ) )
				end
			else
			 Game.inform( look( value, true )[1] )
			end
		end
		
		def list_objects( list, hidden = false )
			if list.class == Array # Assumed an array of gobjects???
				return list.select { |e| e.seen }.map { |e| e.description }.join(", ")
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
			peeker = Adventure::PeekListener.new( @location )
			peeker.do( @gamefile )
			@peek = peeker.peek
			
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
					rem_looked = :looked + "_" + dir
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
				# Check the exit types in this direction
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
				else
					result[1] += @peek.select {|p| p.type == "peek" && p.direction == dir &&
						p.counter > 0 }.map {|p| [dir," ",$cards[p.counter],": ",p.text].join }.join
					result[1] += @peek.select {|p| p.type == "peek" && p.direction == dir && 
						p.counter == 0 }.map {|p| p.text }.join
				end
			else
				result = [-1,"Look where?"]
				@timer += 1.mins
			end
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
		
		# extra information queries
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
				when "inv"
					if @players[0].inventory.size + @players[0].hands.size == 0
						Game.inform("Your inventory is empty.")
					elsif @players[0].inventory.size == 0
					else
						x = Adventure::list_to_english(@players[0].inventory.all_items() )
						Game.inform("Your inventory includes " + x.to_s)
					end
					if @players[0].hands.size > 0
						x = Adventure::list_to_english(@players[0].hands.all_items() )
						Game.inform("You are holding " + x.to_s )
					end
				when "timer", "time"
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
			return if text == []
			if ["in_inv","in_inventory"].intersect?(text)
				manual = "inv"
			elsif ["in_room","in_cave","in_loc","in_location"].intersect?(text)
				manual = "room"
			else
				manual = "both"
			end
			fobj, result = look_for_food( text, manual )
			if result.max == 0
				Game.inform( text[0] + " cannot be found here. ")
				return
			end
			if result.min > 0
				Game.inform( text[0] + " can be found in inventory and location. ")
				Game.inform("Please specify which to take from. ")
				return
			end
			loc = result[0] > 0 ? "room" : "inv"
			if fobj
				effect = fobj.consume( @timer )
				@players[0].adjust(self, effect)
				if fobj.type == "water" && loc == "inv"
					fobj.drain()
				end
				Game.inform("You have consumed some " + text[0] + "." )
				if fobj.quantity == 0
					Game.inform("The resource has been used up. ")
					if fobj.grow.class <= String && fobj.grow != ""
						Game.inform("The resource will replenish. ")
					end
				end
			end
		end

		# Check for food either in room or inventory
		def look_for_food( text, location )
			food = text[0]
			fobj = nil
			result = [0, 0] # Number in [room,inventory]
			# Check room
			if ["room","both"].include?(location)
				food_file( @location ).each do |obj|
					if obj.description == food && obj.check(@timer) > 0 
						fobj = obj
						result[0] = 1
					end
				end
			end
			# Check inventory
			if ["inv","both"].include?(location)
				@players[0].inventory.contents.each do |obj|
					if obj.description == food && obj.check(@timer) > 0
						fobj = obj
						result[1] = 1
					end
				end
				#obj = @players[0].hands.contents[0]
				#if obj.class <= GFood && obj.description == food && obj.check > 0
				#	result[1] = 1
				#end
			end
			return fobj, result
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
					error_message( "Inspect Fail!", e )
				end
			else
				Game.inform( dont_understand() )
			end
		end
		
		def error_message( message = "Error!", error )
		  puts message + ": " + error.class.name + ": " + error.message
		  puts "Call Backtrace:"
		  error.backtrace.each {|line| 
		  	line = line.to_s 
		  	puts "  " + line.to_s[line.to_s.rindex("/")...line.to_s.size] 
		  }
			return 
		end
		
		
		# The goto_room method implements the game's goto command, which is a developer
		# command that allows the programmer to jump from his current location to any
		# other location in the game. The goto command may be called as 'goto <room>' to
		# go to any room in the current file, or 'goto <file>/<room>' to go to any room 
		# in the game, including those in other files. 
		def goto_room( text )
			return if text == [] 
			room = text[0]
			if @config["prog/command.goto"] == "yes"
				if room["/"]
					room = room.split("/")[1]
					set_gamefile( text[0].split("/")[0] )
				end
				if room_exists?( room )
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
