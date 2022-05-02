# inform.rb
#
# This code implements a game messaging system.
# (c)2010 Owein Herrmann
# KittySoft Solutions
# 11-2010
# 
class Inform
	
	def initialize()
		# The formatted text of the buffer
		@text = []
		# The print location of the buffer. Refers to the index within
		# @text that was last resulted.
		@print_location = -1
		# The wrap factor. Currently hardcoded to 70.
		@wrap = 70
	end
	
	attr_reader :text
	
	# Adds a new paragraph of text to the text buffer.
	def para( text = "" )
		@text << text.wrap( @wrap )
		return text.size
	end
	
	# Appends the text to the text buffer, keeping it in the current paragraph.
	def append( text = "" )
		text = @text[ @text.size - 1 ].join(" ") + " " + text
		@text[ @text.size - 1 ] = text.wrap( @wrap )
		return @text.size
	end
	
	# Prepends a new paragraph to the text buffer, after the print-location,
	# so that it will be printed first when the buffer is printed.
	def alert( text = "" )
		text = text.wrap( @wrap )
		@text.insert( @print_location + 1, text )
		return @text.size
	end
	
	# Clears the portion of the text buffer that has already been printed.
	def purge()
		@text = @text[ ( @print_location + 1 )..( @text.size() - @print_location + 2 ) ]
		@print_location = -1
		return nil
	end
	
	def print()
		first = @print_location + 1
		last  = @text.size() - @print_location + 2
		result = @text[ first..last ]
		@print_location += (last - first + 1 )
	end

=begin
	# Returns the formatted text in the print buffer, from the print-location
	# to the end. If an argument is specified, n lines are printed and then 
	# a <more> is displayed. 
	# *** DOES NOT CURRENTLY WORK ***
	def print( lines = 0 )
		first = @print_location + 1
		last  = @text.size() - @print_location + 2
		result = @text[ first..last ]
		result << "<more>" if lines < (last-first+1)
		return result
	end
	
	# Returns 'true' if there is more to send from the print buffer, or false if
	# all the text in the buffer has been printed. This could indicate that no text
	# has been printed, or it could indicate that the text was printed with a 'lines'
	# argument, and there is more in the buffer available to display.
	# *** DOES NOT CURRENTLY WORK ***
  def more?()
		return size_unprinted() > 0
	end
	
	# Returns the number of unprinted lines in the buffer.
	# *** DOES NOT CURRENTLY WORK ***
	def size_unprinted()
		result = size() - ( @print_location + 1 )
		return result
	end
	
	# Returns the total number of lines of text in the buffer.
	def size()
		return @text.size()
	end
=end
end # Inform class

#########################################################################################################
# <string>.wrap( width ) ==> array
# wraps the string to <width> columns and returns it as
# an array, each element being a string of not more than
# <width> characters. A wrapped array can be re-wrapped
# by calling <array>.wrap( width )

class String
	def wrap( width=70, indent=0 )
		indent = " " * indent
		w = []
		x = 0
		while x < self.size do
			xe = width
			xf = (x + xe) <= self.size
			xl = xf ? self[x..x+xe] : nil
			bk = xl ? xl.reverse=~/[\s]/ : 0
			bkf = bk < (width/2)
			bk = 0 unless bk && bkf
			xe -= bk
			xe -= 1 unless bkf
			y = self[x..x+xe].split " "
			z = ""
			s = 0
			y.each do |k|
				s += 1
				if bk > 0 && (y.size > s) && xf
					bkk = ( (bk.to_f/(y.size-s))+0.5).to_i
					kk = " " * bkk
					bk -= bkk
				else
					kk = ""
				end
				ss = s < y.size ? " " : ""
				z += k + ss + kk
			end
			w << z
			x += xe + 1
		end
	w
	end
end

class Array
  def wrap( width=70 )
    if self[0] && self[0].size != width
      ( self.map { |x| x + " " } ).join.squeeze(" ").wrap width
    else
      self
    end
  end
end