module Adventure

	# A door is a barrier between any two rooms that may be crossed provided conditions are met. 
	# A door may have four states: Open, Closed, Locked, Damaged. An open door may be passed through 
	# as easily as an exit. A locked door requires a key or action to unlock and open it. A damaged
	# door cannot be passed through unless you have the ability to fix it. 
	# When you try to go through a closed door, the player automatically opens it and passes though.
	# On the next command, the player may choose to close the door. 
	# If the door is locked, and the player has the key or knows the action, they will automatically
	# unlock, open, and pass through the door. They then have the option of closing, and if closing, 
	# of locking it again. There is however no guarantee that the key or action on the other side of 
	# the door works on this side. 
	# If a door is damaged it cannot be passed through. It is "stuck" or broken. 
	# use:
	# x = GDoor.new("1", "1", true)
	# 
	# to open a door you need a key:
	# y = GKey.new( "1", ["1"], "a key for the cavern door")
	# 
	# success = y.unlock_door( "1" )
	# 
	#   Note: The door id and the key id do not have to be equal, but it helps if they are.
	#   Note: A key being able to open more than one door will be an attribute of the key, not the door
	# A door is defined in two adjoining locations, but there would only be one door object. 
	# The door's state is consistent between the two locations. 
	class GDoor < GObject
		def initialize( id, description = "a doorway", attr = {} )
			super("door", description, attr)
			@id = id.to_i
			@state = "Open"
			@moveable = false
		end
		
		attr_accessor :state 
		attr_reader :id
		
		def open?
			return @state == "Open"
		end
		
		def closed?
			return @state == "Closed"
		end
		
		def locked?
			return @state == "Locked"
		end
		
		def unlocked?
			return @state != "Locked"
		end
		
		def pretty(level=0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name + ":" + self.object_id.to_s
			result += "\n" + indent2 + "@name:" + @name
			result += "\n" + indent2 + "@desc:" + @description
			result += "\n" + indent2 + "@id:" + @id.to_s + " (" + @id.class.name + ")"
			result += "\n" + indent2 + "@state:" + @state.to_s
			result += "\n" + indent2 + "{seen:" + @seen.pretty + ",hidden:" + @hidden.pretty 
			result += ",moveable:" + @moveable.pretty + "}"
			result += "\n" + indent2 + "@attributes:\n" + @attributes.pretty(level + 1)
			result += "\n" + indent + ">"
			return result
		end


	end # GDoor class
	
	class GKey < GObject
		def initialize( id, door_list = [], description = "a key", attr = {} )
			super("key", description, attr)
			@id = id.to_i
			door_list.map! {|door| door.to_i }
			@doors = door_list
		end
		
		attr_reader :id
		attr_accessor :door_list
		
		def unlock_door( door )
			if @doors.include?(door.id)  && door.state == "Locked" && self.try() && door.try()
				door.state = "Unlocked"
				return true
			end
			return false
		end
		
		def lock_door( door )
			if @doors.include?(door.id) && ["Open", "Unlocked"].include?(door.state) && try() && door.try()
				door.state = "Locked"
				return true
			end
			return false				
		end
		
		def key_works?(door)
			return true if @doors.include?(door)  && self.try()
			return false
		end	
		
		def pretty(level = 0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = "\n" + indent + "<" + self.class.name + ":" + self.object_id.to_s
			result += "\n" + indent2 + "@id:" + @id.to_s
			result += "\n" + indent2 + "@name:" + @name
			result += "\n" + indent2 + "@desc:" + @description
			result += "\n" + indent2 + "@doors:" + @doors.inspect
			result += "\n" + indent2 + "{seen:" + @seen.pretty + ",hidden:" + @hidden.pretty 
			result += ",moveable:" + @moveable.pretty + "}"
			result += "\n" + indent2 + "@attributes:\n" + @attributes.pretty(level + 1)
			result += "\n" + indent + ">"
			return result
		end
			
		
	end # GKey class
	
end # Adventure module
