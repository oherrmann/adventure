# game weapons
# 
# 
module Adventure
	
	class GWeapon < GObject
		def initialize( id, name, description, attr={} )
			super( name, description, attr )
			@id = id
			@effect = ""
			@hidden_text = ""
		end

		attr_reader :effect, :hidden_text, :id
		
		# Only allow setting the effect once. 
		def effect=( val )
			if @effect.length > 0
				return false
			else
				@effect = val.to_s
				return true
			end
		end
		
		# Only allow setting the hidden_text once. 
		def hidden_text=( val )
			if @hidden_text.length > 0
				return false
			else
				@hidden_text = val.to_s
				return true
			end
		end
		
		def hit
			# TODO: This would be the method if you use the weapon
			# It's effect is determined by it's @effect variable, whether
			# it's @damaged or not, and possibly the roll of a die. 
		end
		
		def pretty( level = 0 )
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name + ":"
			result += "\n" + indent2 + "@name:" + @name.to_s
			result += "\n" + indent2 + "@desc:" + @description.to_s
			result += "\n" + indent2 + "@damaged:" + @damaged.to_s
			result += "\n" + indent2 + "@id:" + @id.to_s
			result += "\n" + indent2 + "{@seen:" + @seen.pretty + ", @hidden:" + @hidden.pretty 
			result += ", @moveable:" + @moveable.pretty + "}"
			result += "\n" + indent2 + "@attributes:\n" + @attributes.pretty(level + 1)
			result += "\n" + indent + ">"
			return result
		end
		
	end # GWeapon class
end # Adventure module