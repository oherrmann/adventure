# Game food
# 
# x = GFood.new( "mushrooms", 10, "hun=0;ene+10", "1.days" )
# 
# qty = x.check(@timer)
# if qty > 0
# 	effect = consume(@timer)
#   @players[0].adjust(effect)
# else
#   Game.inform("Nothing here to eat. ")
# end
# 
# TODO: Implement alcohol
# 
module Adventure
	class GFood < GObject
		def initialize( type, quantity, effect, grow, attr = {} )
			@type = type
			@name = @type
			@quantity = quantity.to_i
			@original_q = quantity.to_i
			@effect = effect
			@grow = grow
			@poisonous = false
			@refresh = nil
			@seen = false
			@damaged = 0
			@hidden = false
			@moveable = true
			@attributes = {}	
		end
		
		attr_accessor :poisonous, :seen, :original_q
		attr_reader :type, :effect, :quantity, :grow, :refresh
		
		def description
			return @type
		end
		
		def name
			return @type
		end
		
		# [Alcohol]
		def tox
			return @toxic
		end
		
		# [Alcohol]
		def tox=( val )
			@toxic = val.to_i
		end
		
		def is_food?
			return true
		end
		
		def consume( time )
			effect = ""
			if @type != "water" && @quantity > 0
				@quantity -= 1
				effect = @effect
			elsif @type == "water"
				effect = @effect
			end
			# When you eat the last one, the grow cycle (if there is one) restarts
			if @quantity == 0 && @refresh.nil? && @grow != "false"
				@refresh = time.to_i.to_s + ".secs + " + @grow
			end
			return effect
		end
		
		def drain( qty = 1 )
			@quantity -= qty
		end
		
		def fill( qty )
			@quantity = qty
		end
		
		def check( time )
			return @quantity if @quantity > 0
			if @grow == false then return 0 end
			tn = time()
			if tn && time.to_i > tn.to_i
				@quantity = @original_q
				return @quantity
			else
				return 0
			end
		end
		
		# Needed for saving/loading game
		def ref=( val )
			@refresh = val
		end
		
		def pretty( level = 0 )
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name
			result += "\n" + indent2 + "@type:" + @type.to_s
			result += "\n" + indent2 + "@quantity:" + @quantity.to_s
			result += "\n" + indent2 + "@original_q:" + @original_q.to_s
			result += "\n" + indent2 + "@effect:" + @effect.to_s
			result += "\n" + indent2 + "@grow:" + @grow.to_s
			result += "\n" + indent2 + "@poisonous:" + @poisonous.to_s
			result += "\n" + indent2 + "@refresh:" + @refresh.to_s
			result += "\n" + indent2 + "@name:" + @name.to_s
			result += "\n" + indent2 + "@description:" + description().to_s
			result += "\n" + indent2 + "@damaged:" + @damaged.to_s
			result += "\n" + indent2 + "{@seen:" + @seen.pretty + ", @hidden:" + @hidden.pretty 
			result += ", @moveable:" + @moveable.pretty + "}"
			result += "\n" + indent2 + "@attributes:" + @attributes.pretty(level + 1)
			result += "\n" + indent + ">"
			return result
		end
		
		private
		
		def time
			tn = eval(@refresh)
		rescue Exception => e
			return false
		else
			return tn
		end
		
	end # GFood class
end # Adventure module
