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
module Adventure
	class GFood < GObject
		def initialize( type, quantity, effect, grow )
			@type = type
			@quantity = quantity
			@original_q = quantity
			@effect = effect
			@grow = grow
			@poisonous = false
			@refresh = nil
		end
		
		attr_accessor :poisonous
		attr_reader :type, :effect
		
		def is_food?
			return true
		end
		
		def consume( time )
			if @quantity > 0
				@quantity -= 1
				return @effect
			end
			# When you eat the last one, the grow cycle (if there is one) restarts
			if @quantity == 0 && @refresh.nil? && @grow != "false"
				@refresh = time.to_i.to_s + ".secs + " + @grow
				return ""
			else
				return ""
			end
		end
		
		def check( time )
			return @quantity if @quantity > 0
			if @grow == false then return 0
			tn = time()
			if tn && time.to_i > tn.to_i
				@quantity = @original_q
				return @quantity
			else
				return 0
			end
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
