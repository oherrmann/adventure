# 
# gameplayer.rb
# 
# 
#require 'gameplayer'
# Updated 2022.06.05 19:32:25 Changes for multi-direction
# 
module Adventure

	$STATS = /^(exp|ene|sta|hun|ths|experience|energy|stamina|hunger|thirst)/
	$stat_translate = {:exp=>:experience,:ene=>:energy,:sta=>:stamina,:hun=>:hunger,:ths=>:thirst}
	
	class GPlayer < GObject
		def initialize( name )
			super( name, "player" )
			@inventory = Container.new( "inventory", name + "'s inventory" )
			@inventory.seen = true
			@hands = Container.new("hands", "what is in your hands")
			@hands.seen = true
			@last_handled = nil
			@status = {}
			@rooms = []
			@alive = true
			@path = GPath.new(20)
			@location = ""
			@last_location = ""
			@last_direction = ""
			# Strength, Constitution, Dexterity, Intelligence, Wisdom, and Charisma
			#@str, @con, @dex, @int, @wis, @cha = [20] * 6

			@experience = 0.to_f # exp NB: There are all 'Float' class variables
			@energy = 100.to_f   # ene
			@stamina = 100.to_f  # sta
			@hunger = 0.to_f     # hun
			@thirst = 0.to_f     # ths
			
			@next_sleep = nil
			
			@sleep = {
				"<4"=>"ene-10;hun+20;ths+20;sta-50", 
				"<6"=>"hun+20;ths+20;sta-25", 
				"<8"=>"ene+50;hun+20;ths+20", 
				"==8"=>"ene+100;hun+30;ths+30;sta+50", 
				">8"=>"ene-10;hun+50;ths+50;sta-25"}
			
		end
		
		def pretty(level=0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name + ":" + self.object_id.to_s
			result += "\n" + indent2 + "@name:" + @name.to_s
			result += "\n" + indent2 + "@description:" + @description.to_s
			result += "\n" + indent2 + "@location:" + @location.to_s
			result += "\n" + indent2 + "@last_location:" + @last_location.to_s
			result += "\n" + indent2 + "@last_direction:" + @last_direction.to_s
			result += "\n" + indent2 + "@experience:" + @experience.to_s
			result += "\n" + indent2 + "@energy:" + @energy.to_s
			result += "\n" + indent2 + "@stamina:" + @stamina.to_s
			result += "\n" + indent2 + "@thirst:" + @thirst.to_s
			result += "\n" + indent2 + "@hunger:" + @hunger.to_s
			result += "\n" + indent2 + "@next_sleep:" + @next_sleep.out unless @next_sleep.nil?
			result += "\n" + indent2 + "@next_sleep:--:--:--" if @next_sleep.nil?
			result += "\n" + indent2 + "@hands:" + @hands.pretty(level + 1)
			result += "\n" + indent2 + "@inventory:" + @inventory.pretty(level + 1)
			result += indent + ">"
			return result
		end			

		attr_accessor :name, :inventory, :hands, :last_handled, :status, :location, 
			:last_location, :last_direction, :rooms, :path, :experience, :energy, :stamina,
			:thirst, :hunger, :next_sleep
				
		def take( object, hands = false )
			object.seen = true
			if hands
				@hands.add( object )
			else 
				@inventory.add( object )
			end
		end
		
		def drop( object )
			@inventory.drop( object )
		end
		
		def alive?()
			return @alive
		end
		
		def kill_player()
			@alive = false
			notify( :death, self )
		end
		
		# player.go_back? returns the direction the player should go to go back,
		# or false if the player cannot go back.
		def go_back?
			if @path.back
				return Adventure::reverse_direction( @path.back[0] )
			end
			return false
		end
		
		def go_back_room
			if @path.back_room
				return @path.back_room
			end
			return false
		end
		
		# player.go is called when a player goes in a direction. Consideration for the 
		# stack pointer should be taken for 'back' direction.
		def go( direction, room, counter, back = false )
			@path.add( direction, room, counter )
			if back
				@path.backward()
			else
				@path.forward()
			end
		end
		
		# This is called when the player enters a room. It keeps a tab of what rooms
		# the player has been to. 
		def in_room( location )
			@location = location
			if ! been_to?( location )
				@rooms << location
			end
		end
		
		# Returns true of the player has been to this room, otherwise false. 
		def been_to?( location )
			@rooms.include?( location )
		end
		
		# Display the player's stati in a human readable format.
		def status
			%w{experience energy stamina hunger thirst}.map do |attr|
				val = "%6s" % ("%6.2f" % self.send( attr.to_sym ))
				"%12s = %s" % [attr.capitalize, val]
			end
		end

		def status_old
			["strength","constitution","dexterity","intelligence",
				"wisdom","charisma","energy","experience"].map do |attr|
				val = "%5s" % ("%0.2f" % self.send( attr.to_sym ))
				"%12s = %s" % [attr, val]
			end
		end
		
		def sleep( text, timer )
			unless @next_sleep.nil? || (@next_sleep.hrs < timer.hrs )
				return false
			end
			sleep = 8.hrs
			y = false
			over = Die.roll(3)
			under = Die.roll(6)
			x = Die.roll(20)
			if x < 3 then sleep -= under.hrs end
			if x > 18 then sleep += over.hrs end
			@sleep.each_pair do |key,val|
				x = sleep.to_i.to_s + key + ".hrs.to_i"
				begin
					y = eval(x)
				rescue
				end
				if y 
					self.adjust( nil, val )
					break
				end
			end
			@next_sleep = timer + sleep + 12.hrs
			return sleep
		end
		
		# Adjust player stati via text notation: <stat><op><value>
		# Multiple adjustments are separated by semicolons (;)
		# stat = exp, ene, sta, hun, ths
		# you can also send the full stat name:
		# experience, energy, stamina, hunger, and thirst
		# 
		# <stat>+<value>                     Adds <value> to <stat>
		# <stat>-<value>                     Subtracts <value> from <stat>
		# <stat>= < > <= >= <> <value>       Compare <stat> to <value>, stop processing if true
		# <stat>^<value>                     Set stat to value
		#                                    
		# hrs+10 or hours+10 or h+10         Adds hours on to the game timer
		# mins+10 or minutes+10 or m+10      Adds minutes on to the game timer
		# secs+10 or seconds+10 or s+10      Adds seconds on to the game timer
		# die                                kills the player
		# 
		# 
		# 
		# results are in an array. 
		# = 0   means not executed
		# = 1   means successful
		# = -1  error
		# = -2  syntax error
		# requires a self reference from the Game object to adjust the game timer
		# If the call comes from the player (such as in #sleep) then the <object>
		# parameter is set to <nil> and the time adjustment primatives are not available.
		# 
		def adjust( object, text )
			text = text.split(";")
			results = [0]*text.length
			ctr = -1
			text.each do |eff|
				ctr += 1
				if eff =~ $STATS + /([+-])([0-9.]+)/               # Adjust stat up/down
					at, op, ch = $~[1], $~[2], $~[3].to_f
					if op == "-" then ch = 0 - ch end
					call = $stat_translate[at.to_sym] || at.to_sym
					# Symbol#+ is defined in gutils.rb
					begin
						self.send( call + "=", self.send( call ) + ch )
					rescue Exception => e
						Game.inform("There was a problem with the 'effect' code:")
						Game.inform( eff )
						Game.inform( e.class.name + ": " + e.message )
						results[ctr] = -1
					else
						results[ctr] = 1
					end
				elsif eff =~ $STATS + /(=|<|>|<=|>=|<>)([0-9.]+)/  # Stop if stat compare is true
					at, op, ch = $~[1], $~[2], $~[3]
					if op == "<>" then op = "!=" elsif op == "="  then op = "==" end
					call = $stat_translate[at.to_sym] || at.to_sym
					val = (self.send( call )).to_s + op + ch
					begin
						val = eval(val)
					rescue Exception => e
						Game.inform("There was a problem with the 'effect' code:")
						Game.inform( eff )
						Game.inform( e.class.name + ": " + e.message )
						results[ctr] = -1
					else
						results[ctr] = 1
					end
					if val == true then break end
				elsif eff =~ $STATS + /(\^)([0-9.]+)/              # Set stat absolute
					at, op, ch = $~[1], $~[2], $~[3].to_f
					call = $stat_translate[at.to_sym] || at.to_sym
					# op = '^'
					self.send( call + "=", ch.to_f )
					results[ctr] = 1
				elsif eff =~ /^(h[+]|hrs[+]|hours[+])([0-9.]+)/ && not(object.nil?) 
					# 																							Adjust time (hours)
					adj = $~[2]
					object.timer.hours = adj.to_i
					results[ctr] = 1
				elsif eff =~ /^(m[+]|mins[+]|minutes[+])([0-9.]+)/ && not(object.nil?)  
					# 																							Adjust time (minutes)
					adj = $~[2]
					object.timer.minutes = adj.to_i
					results[ctr] = 1
				elsif eff =~ /^(s[+]|secs[+]|seconds[+])([0-9.]+)/ && not(object.nil?) 
					# 																							Adjust time (seconds)
					adj = $~[2]
					object.timer.seconds = adj.to_i
					results[ctr] = 1
				elsif eff == "die"
					kill_player()
				else
					results[ctr] = -2
				end
			end
			return results
		end
		
		def adjust_old( text )
			text.split(";").each do |prim|
				if prim =~ /(str|con|dex|int|wis|cha|ene|exp)([-+])([0-9.]+)/
					at = prim[0..2]
					op = prim[3,1]
					ch = prim[4..-1].to_f
					if op == "-"
						ch = 0 - ch
					end
					call = {:str=>:strength,:con=>:constitution,:dex=>:dexterity,
						:int=>:intelligent,:wis=>:wisdom,:cha=>:charisma,:ene=>:energy,
						:exp=>:experience}[at.to_sym]
					self.send( (call.to_s + "=").to_sym, self.send( call ) + ch )
				elsif prim == "die"
					kill_player()
				end
			end
		end
		
		def energy(); return @energy; end
		def energy=(val)
			if val > 100 
				val=100
			elsif val < 0
				val = 0
			end
			@energy=val
		end

		def stamina(); return @stamina; end
		def stamina=(val)
			val = val.to_f
			if val > 100 
				val=100
			elsif val < 0
				val = 0
			end
			@stamina=val
		end

		def experience(); return @experience; end
		def experience=(val)
			val = val.to_f
			if val > 100 
				val=100
			elsif val < 0
				val = 0
			end
			@experience=val
		end

		def hunger(); return @hunger; end
		def hunger=(val)
			val = val.to_f
			if val > 100 
				val=100
			elsif val < 0
				val = 0
			end
			@hunger=val
		end

		def thirst(); return @thirst; end
		def thirst=(val)
			val = val.to_f
			if val > 100 
				val=100
			elsif val < 0
				val = 0
			end
			@thirst=val
		end
	
	end # GPlayer class
	
	# Currently, the primary use of the GPath class is as a means to implement the 
	# 'go back' command for players. The GPath functions are called from the GPlayer 
	# object above, and a few are called from the Game.move command. References in 
	# Game.move to @players[0].path.<method> should probably be clarified as calls 
	# to methods in GPlayer that call GPath.
	class GPath
		def initialize( maximum )
			@maximum = maximum
			@path = []
			@ptr = 0
		end
		
		def pretty( level = 0 )
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name
			result += "\n" + indent2 + "@maximum:" + @maximum.to_s
			result += "\n" + indent2 + "@ptr:" + @ptr.to_s
			result += "\n" + indent2 + "@path:"
			result += "\n" + indent2 + "["
			@path.each {|val| result += val.to_s + ",\n" + indent2 + " " }
			rl = result.length - indent2.length - 4
			result = result[0..rl]
			result += "]"
			return result
		end
		# GPath.add stacks a direction on the path. It also maintains the size of the stack,
		# and the location of the 'back' pointer. 
		def add( direction, room, counter )
			@path.push( [direction, room, counter] )
			#if @ptr == @path.size-1
			#	@ptr = @path.size
			#end
			while @path.size > @maximum
				@path.shift
				@ptr -= 1 unless @ptr == 0
			end
		end
		# GPath.back returns the direction that the player proceeded in from the path stack. 
		# 'back' will return false if there are no more directions left on the stack.
		def back
			unless @ptr == 0 || @path[@ptr-1] == "back"
				@path[@ptr-1]
			else
				false
			end
		end
		
		# GPath.back_room returns the room that the last move came from.
		def back_room
			unless @ptr == 0 || @path[@ptr-2] == "back"
				@path[@ptr-2][1]
			else
				false
			end
		end
		# GPath.forward is called after a character's move has been confirmed as a forward
		# move, ie, as a non-back move. If the character moves forward, then the backward
		# movement pointer should be reset to the end of the path stack. Also, the path is
		# 'fixed,' ie, all 'back' references are removed, along with the forward moves that 
		# these references backed-out.
		def forward()
			@ptr = @path.size
			fix_path()
		end
		# GPath.backward is called when a character is confirmed to have moved backward. The
		# backward movement pointer is decremented unless there are no more moves to back out.
		def backward()
			@ptr -= 1 unless @ptr == 0
		end
		# Returns the path. Used by 'what path' or 'check path' queries.
		def path
			return @path.map {|move| move[0].to_s + "-" + move[2].to_s + " (room " + move[1].to_s + ")" }
		end
		# Returns the current state of the backward movement pointer. I don't think this is
		# used by anything at the game or player level, I think I just implemented this for
		# a peval call for error checking. @deprecated.
		def pointer
			return @ptr
		end
		# GPath.fix_path is called by the GPath.forward() method to remove 'back' references
		# and the movements that these references backed out. This, in theory, would allow you 
		# to back out, without mis-turns, all the way to the beginning. Of course, we will only
		# allow a limited 'undo' memory.
		def fix_path()
			result = []
			@path.each do |direction|
				direction, room, counter = direction
				if direction == "back"
					result.pop
				else
					result.push( [direction, room, counter] )
				end
			end
			@path = result
			@ptr = @path.size
		end
		
		def clear()
			@path = []
			@ptr = 0
		end
		
	end # Gpath class

end # Adventure module
