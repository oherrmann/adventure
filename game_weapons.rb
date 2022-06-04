# game weapons
# 
# 
module Adventure
	
	class GWeapon < GObject
		def initialize( id, name, description, attr=[] )
			super( name, description, attr )
			@id = id
		end
	end # GWeapon class
end # Adventure module