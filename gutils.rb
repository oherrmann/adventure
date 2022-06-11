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
			print "\"" + f +"\"", " = ", eval(f,block.binding), "\n"
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
			result += ( "\"" + f + "\" = " + eval(f,block.binding).to_s + "\n" )
		end
	end
	return result
end

def deval(&block)
	f = yield
	return eval(f,block.binding).to_s + "\n" 
end

#########################################################################################################
# classes added to base classes to allow "pretty prints"
#
#
class Object
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		result = indent + "<" + self.class.name + ":Object"
		self.instance_variables.each do |field|
			result += "\n" + indent2 + field.to_s + " = "
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
		return "'" + self + "'"
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
	$SYMBOL_SEP = '_'
	def pretty( level = 0 )
		return ":'" + self.to_s + "'"
	end
	# This is just a convenience thing... 
	def +(other)
		return (self.to_s + $SYMBOL_SEP + other.to_s).to_sym
	end
end

class Hash
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		return indent + "{}" if self.size == 0
		result = indent + "{\n" + indent2
		self.each_pair do
			|key, value|
			if key.class <= Numeric
				result += key.to_s
			elsif key.class <= String
				result += "\"" + key.to_s + "\""
			elsif key.respond_to? :pretty
				result += key.pretty( level + 1 )
			else
				result += key.inspect
			end
			result += " => "
			if value.class <= Numeric
				result += value.to_s
			elsif value.class <= String
				result += "'" + key.to_s + "'"
			elsif value.respond_to? :pretty
				result += value.pretty( level + 1 )
			else
				result += value.inspect
			end
			result += ",\n" + indent2
		end
		result = result[0,result.length - indent2.length - 2]
		result += "\n" + indent + "}"
		return result
	end
end

class Numeric
	def pretty( level = 0 )
		indent = ( "  " * level )
		return "\n" + indent + self.to_s
	end
end


class Array
	def pretty( level = 0 )
		indent = ( "  " * level )
		indent2 = ( "  " * ( level + 1 ) )
		return "\n" + indent + "[]" if self.size == 0
		result = "\n" + indent + "["
		self.each do
			|value|
			if value.respond_to? :pretty
				result += value.pretty( level + 1 ) + ", "
			else
				result += indent2 + value.inspect + ", "
			end
		end
		result += "\n" + indent + "]"
		return result
	end
end

#########################################################################################################