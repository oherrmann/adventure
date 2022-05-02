# 
# gameplayer.rb
# 
# 
require 'gameobjects'

module Adventure
	
	module GHuman
		MAX={:str=>20,:con=>20,:dex=>20,
			:int=>20,:wis=>20,:cha=>20}
		RACE="Human"
	end
	module GDwarf
		MAX={:str=>30,:con=>20,:dex=>20,
			:int=>17,:wis=>17,:cha=>20}
		RACE="Dwarvish"
	end
	module GElf
		MAX={:str=>20,:con=>18,:dex=>30,
			:int=>22,:wis=>25,:cha=>20}
		RACE="Elvish"
	end
	module GOrc
		MAX={:str=>22,:con=>15,:dex=>15,
			:int=>10,:wis=>10,:cha=>12}
		RACE="Orkish"
	end
	
	class GPlayer < GObject
		include GHuman
		def initialize( name )
			super( name, "player" )
			@inventory = Container.new( "inventory", name + "'s inventory" )
			@status = {}
			@rooms = []
			@alive = true
			@path = GPath.new(20)
			@location = ""
			@last_location = ""
			@last_direction = ""
			# Strength, Constitution, Dexterity, Intelligence, Wisdom, and Charisma
			@str, @con, @dex, @int, @wis, @cha = [20] * 6
			@experience = 0
			@energy = 100
		end
		
		attr_accessor :name, :inventory, :status, :location, :last_location, :last_direction, :rooms, :path
		
		def take( object )
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
				return Adventure::reverse_direction( @path.back )
			end
			return false
		end
		
		# player.go is called when a player goes in a direction. Consideration for the 
		# stack pointer should be taken for 'back' direction.
		def go( direction, back = false )
			@path.add( direction )
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
		def experience(); return @experience; end
		def experience=(val); @experience=val; end
		
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
		def initialize(maximum)
			@maximum=maximum
			@path=[]
			@ptr=0
		end
		# GPath.add stacks a direction on the path. It also maintains the size of the stack,
		# and the location of the 'back' pointer. 
		def add(direction)
			@path.push direction
			#if @ptr == @path.size-1
			#	@ptr = @path.size
			#end
			if @path.size > @maximum
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
			return @path
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
				if direction == "back"
					result.pop
				else
					result.push  direction
				end
			end
			@path = result
			@ptr = @path.size
		end
		
	end # Gpath class

end # Adventure module
