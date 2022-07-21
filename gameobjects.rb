# 
# 
# Ruby Cave Game objects
# 
# This file is for code that manipulates objects
# 
# pretty



class Object
	def is_gobject?
		return false
	end
	def not_nil?
		if self.class <= NilClass then return false end
		return true
	end
end

module EventDispatcher
	def setup_listeners()
		@subscriptions = {}
	end
	def subscribe( event, &callback )
		( @subscriptions[event.to_sym] ||= [] ) << callback
	end
	protected
	def notify( event, *args )
		if @subscriptions[event.to_sym]
			@subscriptions[event.to_sym].each do |m|
				m.call( *args ) if m.respond_to?( :call )
			end
		end
		return nil
	end
end # module EventDispatcher

module Adventure
	
	# A GObject is a Ruby object that follows a specific contract. 
	class GObject
		include EventDispatcher
		
		def initialize( name, description, attr={} )
			@name = name
			@description = description
			@attributes = attr
			@seen = false
			@hidden = false
			@moveable = true
			@damaged = 0         # Damaged = 0..20; requires a Die.roll(20) to see if it will work.
			setup_listeners()
			@hidden_text
		end
		
		attr_reader :name, :description
		attr_accessor :seen, :hidden, :moveable, :damaged, :subscriptions, :hidden_text
		
		def is_gobject?
			return true
		end
		
		# see if object is _useable_, include param d if using it causes 
		# additional damage.
		def try( d=0 )
			@damaged += d
			@damaged = [ 0, @damaged ].max
			@damaged = [ @damaged, 20 ].min
			return true if @damaged == 0
			return false if @damaged == 20
			ch = Die.roll(20)
			return true if ch > @damaged
			@damaged = 20
			return false
		end
		
		def is_damaged?
			return @damaged > 0
		end
		
		def is_alive?
			return false
		end
		
		def is_container?
			return false
		end
		
		def get_attr( key )
			return @attributes[ key ]
		end
		
		def has_attr?( key )
			return @attributes.has_key?( key )
		end
		
		def set_attr( key, value )
			@attributes[ key ] = value
		end
		
		def unset_attr( key )
			@attributes.delete( key )
		end
		
		def mass_set_attr( attr )
			@attributes = {}
			attr.each_pair {|key,val|
				@attributes[ key.to_sym ] = val
			}
		end
		
		def each_attr
			@attributes.keys.each do |key|
				yield key
			end
		end
		
		def to_s()
			return @name
		end
		
		# Common attributes
		def color=(value)
			@attributes[:color] ||= value
		end
		
		def weight=(value)
			@attributes[:weight] ||= value
		end
		
		def obj_size=(value)
			@attributes[:size] ||= value
		end
		
		def dimensions=(value)
			if value.class.name == "Triple"
				@attributes[:dims] ||= value
			elsif value.class.ancestors.include? Array
				@attributes[:dims] ||= Triple.new( x: value[0], y: value[1], z: value[2] )
			end
		end
		
		def pretty(level=0)
			indent = ( "  " * level )
			indent2 = ( "  " * ( level + 1 ) )
			result = indent + "<" + self.class.name + ":<GObject>"
			result += "\n" + indent2 + "@name:" + @name.to_s
			result += "\n" + indent2 + "@desc:" + @description.to_s
			result += "\n" + indent2 + "@damaged:" + @damaged.to_s
			result += "\n" + indent2 + "{seen:" + @seen.pretty + ",hidden:" + @hidden.pretty 
			result += ",moveable:" + @moveable.pretty + "}"
			result += "\n" + indent2 + "@attributes:\n" + @attributes.pretty(level + 1)
			result += "\n" + indent + ">"
			return result
		end
		
	end # GObject class
	
	
end # Adventure module

=begin
require 'gameplayer'
include Adventure
p = GPlayer.new "Owein"
o1 = GObject.new("ring","a ring")
p.take o1
o2 = GObject.new("key","a key")
o2.set_attr("key", "24")
p.take o2
o3 = GObject.new("key","a key")
o3.set_attr("key", "22")
o3.set_attr("color","blue")
p.take o3
p.inventory.contains?("key")
p.inventory.contains?("key",{"key"=>"22"})
p.inventory.contains?("key",{"key"=>"24"})
p.inventory.contains?("key",{"key"=>nil})
p.inventory.match("ring")
p.inventory.match("key")
p.inventory.match("key",{"key"=>"24"})
=end

