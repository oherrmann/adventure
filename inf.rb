#
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
