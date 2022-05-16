# game.rb
# 
# This is the Ruby Caves Adventure Game. 
# This version uses XML game description files.
require './ditxml'
require './game_grammar'
require './gameobjects'
require './gameplayer'
require './gutils'
require './gamemonster'
require './gtime'
# This line required for jruby, apparently
require 'date'

module Adventure
	$version = "0.1.0"
	LOC_TYPE = 0
	LOC_DEST = 1
	LOC_TEXT = 2
	LOC_FILE = 3
	LOC_DOOR = 4
	LOC_EFFECT = 4
	ACC_TYPE = 0
	ACC_ROLL = 1
	ACC_EFFECT = 2
	ACC_FROM = 3
	ACC_TEXT = 4
	GO_DIRECTION = "*"
	GO_DROPOFF = "f"
	GO_DOORWAY = "d"
	GO_EXTENDS ="e"

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
			@last_text = []
			@last_vars = {}
			@@messages = []
			@players = []
			@room_path = []
			@object_file = {}
			@timer = GTime.new
			@monsters = []
		end
		
		attr_accessor :location, :last_location, :doors
		
		# Loads the configuration file and sets the game id.
		def Game.get_game_config()
			id = 0
			config = []
			config_hash = {}
			begin
				File.open("Config.ini") do |file|
					file.each do |line|
						config << line.chomp
					end
				end
				config.each do |val| 
					u,v = val.split("=")
					config_hash[ u ] = v
				end
				id = config_hash["game.id"].to_i
				config_hash["game.id"] = (id + 1).to_s
				file = File.open("Config.ini","w")
				#config_hash.each_pair do |key,val|
				#	file.write( key + "=" + val + "\n" )
				config.each do |key|
					u,v = key.split("=")
					val = u
					if v
						val += "=" + config_hash[u]
					end
					file.write( val + "\n" )
				end
				file.close
			rescue StandardError => err
				puts( "The configuration file could not be accessed or interpretted: " + err )
			end
			return id,config_hash
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
		def save_room( name, text, vars )
			@rooms[ name.to_sym ] = [ text, vars ]
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
			@last_text = @rooms[ name.to_sym ][0]
			@last_vars = @rooms[ name.to_sym ][1]
		end
		
		# Return the container object for the objects in the room.
		def object_file( name )
			return @object_file[ @gamefile + "/" + name ]
		end
		
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
			@doors[ door ].lock( key )
		end
		
		# Unlocks the door with the key.
		def door_unlock( door, key )
			@doors[ door].unlock( key )
		end
		
		# Returns the id of the key needed to lock/unlock this door.
		def door_key( door )
			return @doors[ door ].key
		end
		
		# Uploads the room from the game definition file. Returns true if the room
		# is loaded, else returns false if the room is not found.
		def upload_room( name )
			loc = LocationListener.new( name )
			if loc.do( @gamefile )
				@last_text = loc.description()
				@last_vars = loc.vars()
				# Only set door info if we haven't already read it.
				doors = loc.doors()
				doors.each_pair do |door,attrs|
					@doors[ door ] ||= Door.new( door, attrs[0], ( attrs[1] == "locked" ) )
				end
				# Create object file if it does not exist. Load objects.
				unless @object_file[ @gamefile + "/" + name ]
					@object_file[ @gamefile + "/" + name ] = Container.new("room","room " + name )
					array = @last_vars["object"]
					objects = []
					if array
						array.each do |ele|
							objects << GObject.new( ele[0], ele[1] )
						end
						@object_file[ @gamefile + "/" + name ].add( objects )
					end
				end
				# We don't need the objects in the room file.
				@last_vars.delete("object")
				save_room( @gamefile+"/"+name, @last_text, @last_vars )
				return true
			else
				return false
			end
		end
		
		def set_location( location )
			@location = location
			@room_path.push( @gamefile+"/"+location )
			room_path_maximum = 100
			if @config["room.path.maximum"]
				room_path_maximum = @config["room.path.maximum"]
			end
			if @room_path.size > room_path_maximum
				room = @room_path.shift
				unless @room_path.member?( room )
					kill_room( room )
				end
			end
		end
		
		# Play the game
		def play( name="Bob", mode = 0, room = @config["start.room"] )
			#break unless @gamefile
			@mode = mode
			@playing = true
			log( Adventure::ts(@config["date.format"]) + " - Game started." )
			@players[0] = GPlayer.new( name )
			@players[0].subscribe( :death ) {|p| @playing = false }
			@players[0].take( GObject.new("torch","a torch") )
			o2 = GObject.new("key","a key")
			o2.set_attr("key", "24")
			@players[0].take o2
			@rooms = {}
			@last_text = []
			@last_vars = {}
			@@messages = []
			@last_location = ""
			set_location( room )
			@input_log = []
			game_intro( room )
			while @playing
				update()
				input = prompt()
				interpret( input )
				other_turns()
			end
			update() if @@messages.size > 0
			log( Adventure::ts(@config["date.format"]) + " - Game ended." )
		end
		
		# Displays info to the user terminal.
		def Game.inform( text = "" )
			if text.class == Array
				@@messages += text
			elsif text.class == String
				@@messages << text
			end
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
			been_to = @players[0].been_to?( @location )
			if room_in_mem?( @gamefile+"/"+@location )
				get_room( @gamefile+"/"+@location )
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
				log( @@messages )
			else
				puts @@messages.wrap(70)
				log( @@messages.wrap(70) )
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
			@original, @adjectives = Adventure::adjust_english( @original )
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
			log( "> " + @original, 1 )
			return "noop" if input.length == 0
			return input
		end
		
		# Interprets the user input.
		def interpret( value = "noop" )
			return nil if @playing == false
			value = value.split(" ")
			command = value.shift
			if Adventure::is_direction?( command )
				value = [ command ]
				command = "go"
			elsif Adventure::to_direction( command )
				value = [ Adventure::to_direction( command ) ]
				command = "go"
			elsif command == "back"
				value = ["back"]
				command = "go"
			end
			@last_command = command
			if command.length > 0
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
					when "consume" then consume( value )
					when "goto" then goto_room( @original.split(" ")[1..-1] )
					when "pinfo" then programmer_info( value )
					when "reload" then reload_room( @original.split(" ")[1..-1] )
					else
						Game.inform( "I do not understand what you mean." )
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
			Game.inform( "location = " + @gamefile + "/" + @location + "\n")
			Game.inform( "time = " + @timer.to_s )
		end
		
		# The take command attempts to pick up objects in a room.
		def take_item( text )
			objects = @object_file[ @gamefile + "/" + @location ]
			#objects.each do |x| puts x.to_s end
			#puts objects.all_items
			@object_file[ @gamefile + "/" + @location ].take_from( text[0], @players[0].inventory )
		end
		
		# The drop command attempts to discard objects in a room.
		def drop_item( text )
			#@players[0].inventory.take_from( gobject, @object_file[ @gamefile + "/" + @location ] )
		end
		
		# Attempts to move the player in a direction
		def move( text )
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
				Game.inform("I do not understand what you mean." )
			end
			@players[0].adjust( "ene-0.5" )
		end
		
		# This routine checks to see if an accident should occur.
		def check_for_accident
			return unless @last_vars["accident"] 
			accident = []
			@last_vars["accident"].each do |acc|
				next if acc[ACC_FROM] && acc[ACC_FROM] != @players[0].last_direction
				accident = acc
				roll = Die.roll( 20 )
				if roll < accident[ACC_ROLL].to_i then accident = [] else break end
			end
			if accident.size > 0
				# The accident has occurred! 
				Game.inform( "Warning: an accident has occured: " + accident[ACC_TYPE] )
				Game.inform( accident[ACC_TEXT] )
				@players[0].adjust( accident[ACC_EFFECT] )
				#@playing = false if @players[0].alive? == false
			end
		end
		
		# ***Not yet implemented***
		# Eamine allows detailed looking at specific objects.
		def examine( text )
		end
		
		# 'look_to' is the basic handler for 'look' commands. There are two modes; 'look <direction>'
		# and 'look around', which looks in all directions. Eventually, 'look <direction>' should cause
		# the interpretter to give more detailed analysis that the more general 'look around'. Also,
		# It should be noted that 'look around' does not look up or down.
		def look_to( value )
			if value[0] == "around"
				vars = @last_vars
				# Check for adjacent rooms ( direction tags )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DIRECTION )
				end
				roomss = rooms.size
				if roomss > 0 then rooms = Adventure::list_to_english( rooms ) end
				if roomss == 1
					Game.inform( "There is a room to the " + rooms + "." )
				elsif roomss > 1 
					Game.inform( "There are rooms to the " + rooms + "." )
				end
				# Check for extended room ( extends tag )
				rooms = []
				dirs = $directions.clone
				while dirs.size > 0
					dir = dirs.shift
					rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_EXTENDS )
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
					rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DOORWAY )
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
					rooms << dir if ( look( [dir] )[0] == 1 && vars[dir][LOC_TYPE] == GO_DROPOFF )
				end
				roomss = rooms.size
				if roomss > 0 then rooms = Adventure::list_to_english( rooms ) end
				if roomss == 1
					Game.inform( "There is a dropoff to the " + rooms + "." )
				elsif roomss > 1 
					Game.inform( "There are dropoffs to the " + rooms + "." )
				end
				# check for objects
				if object_file( @location ).items > 0
					Game.inform( "The following objects can be seen: " + list_objects( object_file( @location ) ) )
				end
			else
			 Game.inform( look( value )[1] )
			end
		end
		
		def list_objects( list )
			if list.class == Array
				return list.map { |e| e[1] }.join( ", ")
			elsif list.class == String
				return list.split(",").map { |e| "a " + e }.join( ", ")
			elsif list.class == Container
				return list.all_items.join( ", " )
			end
		end
		
		# look allows the player to look in a particular direction. If the ambient light level
		# is less than 5 then you cannot see. If it is less than 10 you might not see. Having a
		# torch might improve your chances. look() is called by look_to().
		def look( text )
			#dir = Adventure::is_direction?( text[0] ) if text
			dir = text[0] if ( text && Adventure::is_direction?( text[0] ) )
			result = ""
			to_the = "" 
			if dir != "up" && dir != "down"
				to_the = "to the "
				dir_show = text[0]
			elsif dir == "up"
				dir_show = "above you"
			elsif dir == "down"
				dir_show = "below you"
			end
			if dir
				al = @last_vars["light"].to_i
				al += 10 if @players[0].inventory.contains?( "torch" )
				ch = Die.roll( 20 )
				if @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DIRECTION && al >= 10
					result = [1,"There is an exit #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_EXTENDS && al >= 10
					result = [1,"The room extends #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DOORWAY && al >= 10
					result = [1,"There is a door #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DROPOFF && al >= 10
					result = [1,"There is a dropoff #{to_the}#{dir_show}."]
				elsif ( al >= 5 && al < 10 && ch > 10 )
					result = [0,"You are not able to see anything #{to_the}#{dir_show}."]
				elsif al < 5
					result = [0,"It is too dark for you to see anything."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DIRECTION
					result = [1,"There is an exit #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_EXTENDS
					result = [1,"The room extends #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DOORWAY
					result = [1,"There is a door #{to_the}#{dir_show}."]
				elsif @last_vars[ dir ] && @last_vars[ dir ][LOC_TYPE]==GO_DROPOFF
					result = [1,"There is a dropoff #{to_the}#{dir_show}."]
				else
					result = [0,"You see nothing of interest #{to_the}#{dir_show}."]
				end
			else
				result = [-1,"Look where?"]
			end
			@timer += 5.secs
			return result
		end
		
		# Attempts to describe an object; "what --- "
		def query_object( text )
			if text.member? "status"
				text = ["status"]
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
					Game.inform("You're inventory includes " + @players[0].inventory.all_items().join(", ") )
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
					Game.inform( "I do not understand what you mean." )
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
				Game.inform( "You're current energy level is " + e.to_s )
			elsif text.member?( "food" )
				@players[0].adjust( "ene+50;str+2" )
				Game.inform( "Very tasty! ")
				e = @players[0].energy()
				Game.inform( "You're current energy level is " + e.to_s )
			end
		end
		
		# The int_inspect method implements the game's inspect command, which is a developer
		# command that allows the programmer to view the internal state of the game while it
		# is playing. The inspect command may also be abbreviated to '&'.
		def int_inspect( text )
			text = text.join(" ")
			if @config["command.inspect"] == "yes"
				begin
					Game.inform( reval{text} )
				rescue Exception => e
					Game.inform( "Inspect Fail!: " + e )
				end
			else
				Game.inform( "I do not understand." )
			end
		end
		
		# The goto_room method implements the game's goto command, which is a developer
		# command that allows the programmer to jump from his current location to any
		# other location in the game. The goto command may be called as 'goto <room>' to
		# go to any room in the current file, or 'goto <file>/<room>' to go to any room 
		# in the game, including those in other files. 
		def goto_room( text )
			room = text[0]
			if @config["command.goto"] == "yes"
				if room["/"]
					room = room.split("/")[1]
					set_gamefile( text[0].split("/")[0] )
				end
				if upload_room( room )
					set_location( room )
				else
					Game.inform( "That room cannot be found." )
				end
			else
				Game.inform( "I cannot execute that command in player mode." )
  		end
		end
		
		# The reload_room method allows the developer to reload a room during testing.
		def reload_room( text )
			if text[0]
				if upload_room( text[0] )
					Game.inform( "Room #{text[0]} has been re-loaded." )
				else
					Game.inform( "Room #{text[0]} could not be found in #{@gamefile}." )
				end
			end
		end
		
	end #Game class
	
	
end # Adventure module
