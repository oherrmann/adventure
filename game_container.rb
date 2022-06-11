module Adventure

	class Container < GObject
		def initialize( name, description, contents = [] )
			super( name, description )
			@contents = contents
		end
		
		attr_accessor :contents
		
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
		
		# The #select method implements the Array's #select method on the container contents
		def select( &block )
			return @contents.select( &block )
		end
		
		# Checks to see if the inventory contains an object. It does so by the name of the 
		# object. If the second argument is specified, it looks for a match in the object's
		# attributes. To just see if the object HAS the attribute, send the attribute in 
		# with a value of nil. Unseen objects are not included in results.
		def contains?( gname, attr={} )
			result = 0
			each do |gobject|
				if gobject.seen == true 
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
			end
			return result
		end
		
		# Returns the objects in the inventory that match the specification. The specification
		# is the same as for the contains? method: the first argument is the name, which must
		# match, and the second is a hash of attributes, which must match if the attribute has
		# a value, or must just exist if the attribute is nil. The method returns an array of
		# the objects that match if there is more than one, or just the object if there is only
		# one. Use contains? first to make sure only 1 object matches. Hidden objects are not 
		# included in the results unless hidden == true.
		def match( gname, attr={}, hidden = false )
			result = []
			each do |gobject|
				if gobject.seen == true
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
			end
			return result[0] if result.size == 1
			return result
		end
		
		# Returns the number of items in the container.
		def items
			return @contents.size
		end
		
		alias_method :size, :items
		
		# Returns an array of the descriptions of the objects in the container.
		def all_items( hidden = false )
			results = []
			@contents.each do
				|item|
				if ( item.hidden == true && hidden == true ) || ( item.hidden == false )
					results << item.description 
				end
			end
			return results
		end
		
		# Returns each object contained by the Container.
		def each
			@contents.each do |item|
				yield item
			end
		end
		
		# The take_from method transfers an object from one inventory to another. Usually,
		# it is removing an item from a room inventory and placing it in a character inventory,
		# or removing it from a character inventory and placing it in a room inventory. The
		# 'from' inventory is _self_, and the 'to' inventory is specified as an argument. 
		def take_from( text, to_container )
			#puts $GAME_ADJ.pretty
			if self.contains?( text ) == 1 
				obj = self.match( text )
				self.drop( obj )
				to_container.add( obj )
				Adventure::Game.inform( "A " + obj.name + " has been taken from " + self.name )
				Adventure::Game.inform(" and added to " + to_container.name + ".")
			elsif self.contains?( text ) > 1 && $GAME_ADJ.include?('any')
				objs = self.match( text )
				obj = objs[0]
				self.drop( obj )
				to_container.add( obj )
				Adventure::Game.inform( "A " + obj.name + " has been taken from " + self.name )
				Adventure::Game.inform (" and added to " + to_container.name + ".")
			elsif self.contains?( text ) > 1
				Adventure::Game.inform( "There is more than one item that matches your request." )
			else
				Adventure::Game.inform( "There are no items that match your request." )
			end
		end
		
		def take_specific_from( text, to_container )
		end
		
		def pretty( level = 0 )
			indent = ( "  " * level )
			indent2 = ( "  " *  ( level + 1 ) )
			result = "\n" + indent + "#<Adventure::" + self.class.name
			result += "\n" + indent2 + "@name:" + @name
			result += "\n" + indent2 + "@description:" + @description
			result += "\n" + indent2 + "@contents:" + @contents.pretty(level+1)
			result += "\n" + indent + ">"
			return result
		end
		
	end # Container class
	
	class Room < Container
		def initialize( name, description, contents = [] )
			super( name, description )
			@contents = contents
			@moveable = false
		end
				
		def to_s
			return @contents
		end

	end # Room class
	
	class Pair
		def initialize( x=0, y=0 )
			@x = x
			@y = y
		end
		
		def set( x=0, y=0 )
			@x = x
			@y = y
		end
		
		def reset
			@x = @y = 0
		end
		
		def equ( z )
			return Pair.new(0,0) unless z.class.ancestors.include? Pair
			@x = z.x
			@y = z.y
			return self
		end
		
		def x
			return @x
		end
		
		def y
			return @y
		end
		
		def x=(a)
			@x = x
		end
		
		def y=(y)
			@y = y
		end
		
	end # Pair class

	class Triple
		def initialize( x: 0, y: 0, z: 0 )
			@x = x; @y = y; @z = z
		end
		
		def set( x: 0, y: 0, z: 0 )
			@x = x; @y = y; @z = z
		end
		
		def reset
			@x = @y = @z = 0
		end
		
		def equ( z )
			return Triple.new unless z.class.ancestors.include? Triple
			@x = z.x; @y = z.y; @z = z.z
			return self
		end
		
		def x
			return @x
		end
		
		def y
			return @y
		end
		
		def z
			return @z
		end
		
		def x=(a)
			@x = x
		end
		
		def y=(y)
			@y = y
		end
		
		def z=(z)
			@z = z
		end
		
	end # Triple class
end