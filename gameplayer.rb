# 
# gameplayer.rb
# 
# 
#require 'gameplayer'
# Updated 2022.06.05 19:32:25 Changes for multi-direction
# 
module Adventure
	
	class GPlayer < GObject
		def initialize( name )
			super( name, "player" )
			@inventory = Container.new( "inventory", name + "'s inventory" )
			@hands = Container.new("hands", "what is in your hands")
			@last_handled = nil
			@status = {}
			@rooms = []
			@alive = true
			@path = GPath.new(20)
			@location = ""
			@last_location = ""
			@last_direction = ""
			# Strength, Constitution, Dexterity, Intelligence, Wisdom, and Charisma
			@str, @con, @dex, @int, @wis, @cha = [20] * 6

			@experience = 0 # exp
			@energy = 100   # ene
			@stamina = 100  # sta
			@hunger = 0     # hun
			@thirst = 0     # ths
			
		end
		
		def pretty(level=0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name + ":" + self.object_id.to_s
			result += "\n" + indent2 + "@name:" + @name
			result += "\n" + indent2 + "@desc:" + @description
			result += "\n" + indent2 + "@lctn:" + @location
			result += "\n" + indent2 + "@last_location:" + @last_location
			result += "\n" + indent2 + "@last_direction:" + @last_direction
			result += "\n" + indent2 + "@experience:" + @experience.to_s
			result += "\n" + indent2 + "@energy:" + @energy.to_s
			result += "\n" + indent2 + "@stamina:" + @stamina.to_s
			result += "\n" + indent2 + "@thirst:" + @thirst.to_s
			result += "\n" + indent2 + "@hunger:" + @hunger.to_s
			result += "\n" + indent2 + "@hands:" + @hands.pretty(level + 1)
			result += "\n" + indent2 + "@inventory:" + @inventory.pretty(level + 1)
			result += indent + ">"
			return result
		end			

		attr_accessor :name, :inventory, :hands, :last_handled, :status, :location, 
			:last_location, :last_direction, :rooms, :path, :experience, :energy, :stamina,
			:thirst, :hunger
				
		def take( object )
			object.seen = true
			@inventory.add( object )
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
			"experience,energy,stamina,hunger,thirst".split(",").map do |attr|
				val = "%5s" % ("%0.2f" % self.send( attr.to_sym ))
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
		
		# Adjust is a convenience method. Given a notation like "str-0.1" convert to
		# strength=strength-1 and update the player. Other effects on the player can
		# also be performed, like "die" will kill the player. 
		def adjust( text )
			text.split(";").each do |eff|
				if eff =~ /(exp|ene|sta|hun|ths|experience|energy|stamina|hunger|thirst)([+-])([0-9.]+)/
					at, op, ch = $~[1], $~[2], $~[3].to_i
					if op == "-" then ch = 0 - ch end
					call = {:exp=>:experience,:ene=>:energy,:sta=>:stamina,
						:hun=>:hunger,:ths=>:thirst}[at.to_sym]
					call = at.to_sym if call.nil?
					# Symbol#+ is defined in gutils.rb
					begin
						$SYMBOL_SEP = ''
						self.send( call + "=", self.send( call ) + ch )
					rescue Exception => e
						Game.inform("There was a problem with the 'effect' code:")
						Game.inform( eff )
						Game.inform( e.class.name + ": " + e.message )
					ensure
						$SYMBOL_SEP = '_'
					end
				elsif eff == "die"
					kill_player()
				end
			end
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
		
		
		def strength(); return @str; end
		def constitution(); return @con; end
		def dexterity(); return @dex; end
		def intelligence(); return @int; end
		def wisdom(); return @wis; end
		def charisma(); return @cha; end
		def all_attr(); return [@str, @con, @dex, @int, @wis, @cha]; end
		def strength=(val)
			val=[val,MAX[:str]].min
			@str=val
			case @str.to_f / MAX[:str] * 100
				when 0...20 then notify( :"strength<20%", self )
				when 20...50 then notify( :"srength<50%", self )
			end
		end
		def constitution=(val); val=[val,MAX[:con]].min; @con=val; end
		def dexterity=(val); val=[val,MAX[:dex]].min; @dex=val; end
		def intelligence=(val); val=[val,MAX[:int]].min; @int=val; end
		def wisdom=(val); val=[val,MAX[:wis]].min; @wis=val; end
		def charisma=(val); val=[val,MAX[:cha]].min; @cha=val; end
		def all_attr=(val); @str, @con, @dex, @int, @wis, @cha = val; end
		def energy(); return @energy; end
		def energy=(val)
			if val > 100 then val=100 end
			if val < 0 then val = 0 end
			@energy=val
			case @energy
				when 0 then nil
				when 1...10 then notify( :"energy<10", self )
				when 10...20 then notify( :"energy<20", self )
				when 20...50 then notify( :"energy<50", self )
			end
		end
		
=begin
	GPlayer events
		:death
		:energy<50
		:energy<20
		:energy<10
		:strength<50%
		:strength<20%

=end
		
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
