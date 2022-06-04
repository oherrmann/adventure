# 
# gtime.rb
# 
# A GTime object is meant to hold elapsed time, in seconds. With the methods defined
# here you could easily say:
# 
# e = 10.hrs + 30.mins + 10.secs
# 
class GTime
	
	# Create a GTime object
	def initialize()
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
	
	def out
		x = self.hms
		x[1] = ('0' + x[1].to_s)[-2,2]
		x[2] = ('0' + x[2].to_s)[-2,2]
		return x[0].to_s + ":" + x[1] + ":" + x[2]
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

class Date
  SECONDS_IN_DAY = 86400
  def self.day_fraction_to_time(fr)
    ss,  fr = fr.divmod(86_400) # 4p
    h,   ss = ss.divmod(3600)
    min, s  = ss.divmod(60)
    return h, min, s, fr
  end
end

