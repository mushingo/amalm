require "rubygems"
require "nokogiri"
require "open-uri"
require "restclient"
require "json"


def outputMangaList(hash)
	r = ""
	base =  "https://myanimelist.net/manga/"
	hash.each {|number, name|
		r += "[url=" + base + number.to_s + "]" + name + "[/url]\n"
	}
	return r
end

def outputRejectedMangaList(hash)
	r = ""
	hash.each{|number, name|
		puts number
		puts name
		r += name.to_s + " (" + (number.to_s) + ") - \n"
	}
	return r
end

def addCounts(r, pending, approved, rejected)
	r += "There are " + pending.length.to_s + " manga in the pending queue.\n"
	r += approved.length.to_s + " manga have been approved.\n"
#	r += rejected.length.to_s + " manga have been rejected.\r\n"

	r += "The current time is: " + (Time.now.utc).to_s
	return r
end



def createOutput(new_approved, new_rejected, still_pending, new_pending, old_highest)
	space = "\n\n"

	r = "The following manga have been newly approved since I last checked: \n"
	r += outputMangaList(new_approved)
	r += space
	r += "The following manga were rejected: \n"
	r += outputRejectedMangaList(new_rejected)
	r += space

	new_highest = getHighestNumber(new_approved, new_pending, new_rejected)
	puts new_highest
	puts old_highest
	if new_highest == nil 
		r += "No new manga were submitted.\n"	
	else
		increase = new_highest - old_highest
		if increase > 0
			r += "A total of " + increase.to_s 
			r += " new manga were submitted for approval.\n"
		else
			r += "No new manga were submitted.\n"
		end
	end
	r += space

	r += "The following manga are newly pending \n"
	r += outputMangaList(new_pending)

	r += space

#	r += "The following manga are still pending \n"
#	r += outputMangaList(still_pending)

	r += space

	return r

end


def getWebsiteResponse(number) 
	base_manga_url =  "https://myanimelist.net/manga/"
	manga_url = base_manga_url + number.to_s
	attempts = 0

	while attempts < 10 do 
		attempts += 1

		begin 
			response = RestClient.get(manga_url) {|res, request, result, &block|
				case res.code
				when 200
					res
				when 404
					nil
				else	
					File.open("error.log", "a") do |f|
						f.write(res.code.to_json)
					end
					res = 0				
				end
			}
	
		rescue RestClient::ExceptionWithResponse => err
			File.open("error.log", "a") do |f|
				f.write(err.to_json)
			end
			response = 0
		end

		if response == 0
			sleep(attempts * 3)
			print "attempting again\n"

		else
			break
		end
	end

	return response	

end

def getHighestNumber(approved, pending, rejected)
	return ((approved.keys + pending.keys + rejected.keys).map(&:to_i).max)
end

def writeToFile(approved, pending, rejected, output)
		highest = getHighestNumber(approved, pending, rejected)
		suffix = ".json"
		
		File.open("approved" + suffix, "w") do |f|
			f.write(approved.to_json)
		end
		File.open("pending" + suffix, "w") do |f|
			f.write(pending.to_json)
		end
		File.open("rejected" + suffix, "w") do |f|
			f.write(rejected.to_json)
		end
		File.open("highest" + suffix, "w") do |f|
			f.write(highest.to_json)
		end
		File.open("output_log.txt", "a") do |f|
			f.write(output)
		end
		File.open("output.txt", "w") do |f|
			f.write(output)
		end


end

def isPending(page)
	ranked = page.css('span.numbers:nth-child(1) > strong:nth-child(1)').text.strip
	popularity = page.css('span.numbers:nth-child(2) > strong:nth-child(1)').text.strip
	members = page.css('span.numbers:nth-child(3) > strong:nth-child(1)').text.strip

	if ranked == "#0" || popularity == "#0" 
		return true
	else
		return false
	end


end

def addUnknowns(rejected, unknown) 
	unknown.each { |number|
		rejected[number] = 0
	}
	return rejected
end


pending = JSON.parse(File.read("pending.json"))
rejected = JSON.parse(File.read("rejected.json"))
approved = JSON.parse(File.read("approved.json"))

puts "read in files"

new_approved = {}
new_rejected = {}
still_pending = {}
new_pending = {}

total = pending.length
upto = 1
pending.each { |number, name|
	upto += 1
	response = getWebsiteResponse(number)

	if upto % 20 == 0
		print "checked " + upto.to_s + " of " + total.to_s + " (" +
			((upto.to_f/total.to_f)*100.0).round(2).to_s + "%)\n"
	end


	if response == nil
		new_rejected[number] = name
		print number.to_s + ": " + name + ", was rejected\n"
		next
	else
		page = Nokogiri::HTML(response)
		if isPending(page)
			still_pending[number] = name
		else 
			new_approved[number] = name
			print number.to_s + ": " + name + ", was approved\n"
		end
	end
}
unknown = []
unknowns_in_a_row = 0
old_highest = getHighestNumber(approved, pending, rejected)

puts "checking newly added"
manga_number = old_highest + 1
while unknowns_in_a_row < 30 do
	response = getWebsiteResponse(manga_number)

	if response == nil
		unknowns_in_a_row += 1
		unknown.push(manga_number)
		manga_number += 1
		next
	end

	page = Nokogiri::HTML(response)
	unknowns_in_a_row = 0
	new_rejected = addUnknowns(new_rejected, unknown)
	unknown = []

	name = page.css('h1 span[itemprop="name"]')[0].text
	print manga_number.to_s + ": " + name + "\n"


	if isPending(page)
		new_pending[manga_number] = name
	else
		new_approved[manga_number] = name
	end

	manga_number += 1

end

output = createOutput(new_approved, new_rejected,  still_pending, new_pending, old_highest)

pending = still_pending
pending.merge!(new_pending)
approved.merge!(new_approved)
rejected.merge!(new_rejected)

output = addCounts(output, pending, approved, rejected) 

writeToFile(approved, pending, rejected, output)



