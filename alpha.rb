require "rubygems"
require "json"

def outputMangaList(array)
	total = 0
	count = 0
	index = 1
	r = ""
	base = "https://myanimelist.net/manga/"
	old = 0
	array.each {|x| 
		total += 1
		name = x[1]
		r+= "[url=" + base + x[0] + "]" + name + "[/url]\n"
		if old != name
			count += 1
			if r.size > 55000
				File.open("pending_list-" + index.to_s + ".txt", "w") do |f|
					f.write(r)
				end
				index += 1
				r = ""
			end

		end
		old = name
	}
	puts total
	puts count
	File.open("pending_list-" + index.to_s + ".txt", "w") do |f|
		f.write(r)
	end
	return r
end

pending = JSON.parse(File.read("pending.json"))

pending = pending.to_a 

pending = pending.sort { |x,y| 
	x[1].downcase <=> y[1].downcase
}

r = outputMangaList(pending)




