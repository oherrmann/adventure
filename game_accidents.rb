# game accidents
# 
# 
module Adventure
	class GAccident # not a "GObject"
		def initialize( type, roll, effect, source, text="" )
			@type = type.to_s
			@roll = roll.to_i
			@effect = effect.to_s
			@source = source.to_s
			@text = text.to_s
			@die = 20
		end
		
		attr_reader :type, :roll, :effect, :source, :text, :die
		
	end
end # Adventure module