# 
# gutils.rb
# 
# KittySoft Solutions
# 
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

#########################################################################################################
# 
# peval.rb
# 
def peval(&block)
	f = yield
	f.split(";").each do |f| 
		if f == "[sep]"
			print "-" * 70 + "\n"
		else
			print f, " = ", eval(f,block.binding), "\n"
		end
	end
end

def reval(&block)
	result = ""
	f = yield
	f.split(";").each do |f|
		if f == "[sep]"
			result += "-" * 70 + "\n"
		else
			result += ( f + " = " + eval(f,block.binding).to_s + "\n" )
		end
	end
	return result
end

#########################################################################################################
# A GTime object is meant to hold elapsed time, in seconds. With the methods defined
# here you could easily say:
# 
# e = 10.hrs + 30.mins + 10.secs
# 
class GTime
	
	include Comparable
	
	# Create a GTime object
	def initialize( s="" )
		@time = 0
	end
	
	# Reset the GTime object to its initial state
	def reset
		@time = 0
		return self
	end
	
	# Set the hours of the GTime object. The number of hours are added
	# to whatever is currently in the object.
	def hours=(hours)
		if hours.respond_to?( :to_i )
			@time += ( hours.to_i * 3600 )
		end
		return self
	end
	
	# Set the minutes of the GTime object. The number of minutes are added
	# to whatever is currently in the object.
	def minutes=(minutes)
		if minutes.respond_to?( :to_i )
			@time += ( minutes.to_i * 60 )
		end
		return self
	end
	
	# Set the seconds of the GTime object. The number of seconds are added
	# to whatever is currently in the object.
	def seconds=(seconds)
		if seconds.respond_to?( :to_i )
			@time += ( seconds.to_i )
		end
		return self
	end
	
	# Set the days of the GTime object. The number of days are added
	# to whatever is currently in the object.
	def days=( days )
		if days.respond_to?( :to_i )
			@time += ( days.to_i * 86400 )
		end
		return self
	end
	
	# Sets the GTime object from an array of integers corresponding to the 
	# hours, minutes, and seconds. This is handy for setting the GTime to an
	# elapsed time as Date.day_fraction_to_time( DateTime.now - <DateTime> )
	# returns the elapsed time in this format, so we could say:
	# > f = GTime.new
	# > t = DateTime.now
	# ... something happens that we want to measure elapsed time...
	# > f.hms = Date.day_fraction_to_time( DateTime.now - t )
	def hms=( hms )
		self.reset
		if Array === hms
			self.hours = hms.shift
			self.minutes = hms.shift
			self.seconds = hms.shift
		end
		return self
	end
	
	# Allows you to set the GTime object with the days, hours, minutes, seconds.
	def dhms=( dhms )
		self.reset
		if Array === hms
			self.days = dhms.shift
			self.hours = dhms.shift
			self.minutes = dhms.shift
			self.seconds = dhms.shift
		end
		return self
	end
	
	# Returns the hours field
	def hrs
		return @time / 3600
	end
	
	# Returns the minutes field
	def mins
		return ( @time - ( self.hrs * 3600 ) ) / 60
	end
	
	# Returns the seconds field
	def secs
		return @time % 60
	end
	
	# Returns the days field
	def days
		return self.hrs / 24
	end
	
	# Returns the elapsed hours, minutes, and seconds of the GTime object as
	# an array of integers.
	def hms
		return [ self.hrs, self.mins, self.secs ]
	end
	
	# Returns the elapsed days, hours, minutes, and seconds of the GTime object as
	# an array of integers.
	def dhms
		return [ self.days, self.hrs - ( self.days * 24 ), self.mins, self.secs ]
	end
	
	# Returns the GTime object as an integer, number of seconds
	def to_i
		return @time
	end
	
	# Adds any value that can be interpretted as an integer to a GTime object.
	def +( other )
		result = GTime.new
		if GTime === other || other.respond_to?( :to_i )
			result.seconds = self.to_i + other.to_i
		end
		return result
	end
	
	# Subtracts any value that can be interpretted as an integer from a GTime object.
	def -( other )
		result = GTime.new
		if GTime === other || other.respond_to?( :to_i )
			result.seconds = self.to_i - other.to_i
		end
		return result
	end
	
	# Returns a programmer-readable representation of a GTime object.
	def inspect
		return "#<GTime: " + @time.to_s + ">"
	end
	
	# For Comparable mixin
	def <=>( other )
		return self.to_i <=> other.to_i
	end
	
end # GTime class

class Numeric
	def secs
		result = GTime.new
		result.seconds = self
		return result
	end
	def mins
		result = GTime.new
		result.seconds = self * 60
		return result
	end
	def hrs
		result = GTime.new
		result.seconds = self * 3600
		return result
	end
	def days
		result = GTime.new
		result.seconds = self * 86400
		return result
	end
end # Numeric class

#########################################################################################################
# classes added to base classes to allow "pretty prints," and classes
# to allow wrapping of text.
# oh yes, and it's an unholy mess
# 
class Object
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		result = "\n" + indent + "<" + self.class.name + ":" + self.object_id.to_s
		self.instance_variables.each do |field|
			result += "\n" + indent2 + field + " = "
			value = self.send( :instance_variable_get, field.to_sym )
			if value.respond_to? :pretty
				result += value.pretty( level + 1 )
			else
				result += value.inspect
			end
		end
		result += "\n" + indent + ">"
		return result
	end
end

class String
	def pretty( level = 0 )
		indent = ( "  " * level )
		return "\"" + self + "\""
	end
end

class FalseClass
	def pretty( level = 0 )
		return "false"
	end
end

class TrueClass
	def pretty( level = 0 )
		return "true"
	end
end

class NilClass
	def pretty( level = 0 )
		return "nil"
	end
end

class Symbol
	def pretty( level = 0 )
		return ":" + self.to_s
	end
end

class Hash
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		return "{}" if self.size == 0
		result = "\n" + indent + "{"
		self.each_pair do
			|key, value|
			result += "\n"
			if key.respond_to? :pretty
				result += indent2 + key.pretty( level + 1 )
			else
				result += indent2 + key.inspect
			end
			result += " => "
			if value.respond_to? :pretty
				result += value.pretty( level + 1 )
			else
				result += value.inspect
			end
		end
		result += "\n" + indent + "}"
		return result
	end
end

class Numeric
	def pretty( level = 0 )
		return self.to_s
	end
end


class Array
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		return "[]" if self.size == 0
		result = "\n" + indent + "["
		self.each do
			|value|
			result += "\n"
			if value.respond_to? :pretty
				result += indent2 + value.pretty( level + 1 )
			else
				result += indent2 + value.inspect
			end
		end
		result += "\n" + indent + "]"
		return result
	end
end

#########################################################################################################