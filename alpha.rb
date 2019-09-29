require "rubygems"
require "json"

def findDupes(array)
	duplicates = {}
	array.each {|x|
		name = x[1].downcase
		old_value = duplicates[name]
		if old_value == nil
			old_value = 0
		end
		duplicates[name] = old_value + 1
	}

	duplicates = duplicates.to_a.sort {|a,b| b[1] <=> a[1]}
	r = ""
	duplicates.each {|entry| 
		r += entry[0] + ": " + entry[1].to_s + "\n"
	}
	File.open("duplicates.txt", "w") do |f| 
		f.write(r)
	end	

end


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
		count += 1
		if r.size > 60000
			File.open("pending_list-" + index.to_s + ".txt", "w") do |f|
				f.write(r)
			end
			index += 1
			r = ""
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



findDupes(pending)

