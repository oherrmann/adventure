# 
# 
# gamemonster.rb
# 
# Classes and methods for working with the monsters in our life.
# 
module Adventure

	# The Wheel class models a circular wheel that can be spun to the left or right. 
	# w = Wheel.new([:n,:ne,:e,:se,:s,:sw,:w,:nw])
	# w.roll( 5 )
	# w.read
	class Wheel
		
		def initialize( wheel )
			@wheel = wheel
			@roll = 0
		end
		
		def roll( n=0 )
			raise ArgumentError,"Integer Argument Required for Wheel.roll()" unless n.respond_to?( :to_i )
			n = n.to_i
			@roll += n
			@roll = @roll % @wheel.size
			return self.read()
		end
		
		# The first element in the array is considered to be the one the wheel "pointer" is
		# pointing to.
		def read
			return @wheel[@roll]
		end
	end
	
	class GMonster < GObject
		def initialize( name, type )
			@name = name
			@type = type # type can be 1, 2, or 3.
			@location = nil
			@path = GPath.new( 30 )
			@alive = true
			@wheel = Wheel.new( [:n,:ne,:e,:se,:s,:sw,:w,:nw] )
		end
		
		def is_alive?
			return @alive
		end
		
		# The 'play' method is the monster's turn
		def play()
			case type
				when 1
					play_one()
				when 2
					play_two()
				when 3
					play_three()
			end
		end
		
		# Monster type 1 does not move from his spot.
		def play_one
		end
		
		def play_two
		end
		
		def play_three
		end
		
	end # GMonster class
	
end # Adventure module

