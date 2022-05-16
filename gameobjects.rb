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
			setup_listeners()
		end
		
		attr_reader :name, :description
		
		def is_gobject?
			return true
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
		
		
		def to_s()
			return @name
		end
		
	end # GObject class
	
	class Container < GObject
		def initialize( name, description, contents = [] )
			super( name, description )
			@contents = contents
		end
		
		def is_container?
			return true
		end
		
		# Adds an object to the inventory if the argument is an object,
		# or multiple objects if the argument is an array. 
		def add( gobject )
			if GObject >= gobject.class
				@contents << gobject
				return true
			elsif
				Array >= gobject.class
				gobject.each do |item|
					add item
				end
				return true
			else
				return false
			end
		end
		
		# removes an object from the inventory
		def drop( gobject )
			@contents -= [ gobject ]
		end
		
		# Checks to see if the inventory contains an object. It does so by the name of the 
		# object. If the second argument is specified, it looks for a match in the object's
		# attributes. To just see if the object HAS the attribute, send the attribute in 
		# with a value of nil.
		def contains?( gname, attr={} )
			result = 0
			each do |gobject|
				if gobject.name == gname
					if attr.size > 0
						attrs = attr.size
						attrr = 0
						attr.each_pair do |key,value|
							if value == nil
								attrr += 1 if gobject.has_attr?( key )
							else
								attrr += 1 if gobject.get_attr( key ) == value
							end
						end
						result += 1 if attrs == attrr
					else
						result += 1
					end
				end
			end
			return result
		end
		
		# Returns the objects in the inventory that match the specification. The specification
		# is the same as for the contains? method: the first argument is the name, which must
		# match, and the second is a hash of attributes, which must match if the attribute has
		# a value, or must just exist if the attribute is nil. The method returns an array of
		# the objects that match if there is more than one, or just the object if there is only
		# one. Use contains? first to make sure only 1 object matches. 
		def match( gname, attr={} )
			result = []
			each do |gobject|
				if gobject.name == gname
					if attr.size > 0
						attrs = attr.size
						attrr = 0
						attr.each_pair do |key,value|
							if value == nil
								attrr += 1 if gobject.has_attr?( key )
							else
								attrr += 1 if gobject.get_attr( key ) == value
							end
						end
						result << gobject if attrs == attrr
					else
						result << gobject
					end
				end
			end
			return result[0] if result.size == 1
			return result
		end
		
		# Returns the number of items in the container.
		def items
			return @contents.size
		end
		
		# Returns an array of the descriptions of the objects in the container.
		def all_items
			results = []
			@contents.each do
				|item|
				results << item.description
			end
			return results
		end
		
		# Returns each object contained by the Container.
		def each
			@contents.each do
			 |item|
			 yield item
			end
		end
		
		# The take_from method transfers an object from one inventory to another. Usually,
		# it is removing an item from a room inventory and placing it in a character inventory,
		# or removing it from a character inventory and placing it in a room inventory. The
		# 'from' inventory is _self_, and the 'to' inventory is specified as an argument. 
		def take_from( gobject, to_container )
			if self.contains?( gobject ) == 1
				obj = self.match( gobject )
				self.drop( obj )
				to_container.add( obj )
				Adventure::Game.inform( "A " + obj.name + " has been taken from " + self.name )
				Adventure::Game.inform (" and added to " + to_container.name + ".")
			elsif self.contains?( gobject ) > 1
				Adventure::Game.inform( "There is more than one item that matches your request." )
			else
				Adventure::Game.inform( "There are no items that match your request." )
			end
		end
		
		def pretty( level = 0 )
			indent = ( "  " * level )
			indent2 = ( "  " *  ( level + 1 ) )
			result = indent + "#<Adventure::Container:" + @name 
			result += "\n" + indent2 + "@description:" + @description
			result += "\n" + @contents.pretty(level+1)
			result += "\n" + indent + ">"
			return result
		end
		
	end # Container class
	
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

