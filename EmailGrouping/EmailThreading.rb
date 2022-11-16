# Import your dependencies
require 'dotenv/load'
require 'nylas'
require 'sinatra'
require 'nokogiri'
require 'date'

# Initialize your Nylas API client
nylas = Nylas::API.new(
    app_id: ENV["CLIENT_ID"],
    app_secret: ENV["CLIENT_SECRET"],
    access_token: ENV["ACCESS_TOKEN"]
)

# Use the Nokogiri gem to clean up the email response
def clean_content(raw_html)
	html = raw_html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '', universal_newline: true).gsub(/\P{ASCII}/, '')
	parser = Nokogiri::HTML(html, nil, Encoding::UTF_8.to_s)
	parser.xpath('//script')&.remove
	parser.xpath('//style')&.remove
	parser.xpath('//text()').map(&:text).join('<br> ')
end

# Get the contact associated to the email address
def get_contact(nylas, email)
	contact =  nylas.contacts.where(email: email)
	if contact[0] != nil
		return contact[0]
	end
end

# Download the contact picture if it's not stored already
def download_contact_picture(nylas, id)
	if id != nil
		contact = nylas.contacts.find(id)
		picture = contact.picture
		file_name = id + ".png"
		File.open("public/" + file_name,"wb") do |f|
			f.write File.open(picture, 'rb') {|file| file.read }
		end
	end
end

# When calling the application for the first time
get '/' do
	_threads = []
    # Call the page
	erb :main, :layout => :layout, :locals => {:threads => _threads}
end

# When asking for the email threading
post '/search' do
    # Get parameter from form
	search = params[:search]
    # Search all threads related to the email address	
	threads = nylas.threads.where(from: search,in: 'inbox')	
	
	_threads = []

    # Loop through all the threads	
	threads.each{ |thread|
		_thread = []
		_messages = []
		_pictures = []
		_names = []
        # Look for threads with more than 1 message		
		if thread.message_ids.length() > 1
            # Get the subject of the first email		
			_thread.push(thread.subject)
            # Loop through all messages contained in the thread			
			thread.message_ids.each{ |message|
                # Get information from the message			
				message = nylas.messages.find(message)
                # Try to get the contact information				
				contact = get_contact(nylas, message.from[0].email)
				if contact != nil and contact != ""
                    # If the contact is available, downloads its profile picture				
					download_contact_picture(nylas, contact.id)
				end
                # Remove extra information from the message like appended message, email and phone number				
				_messages.push(clean_content(message.body).
				gsub(/(\bOn.*\b)(?!.*\1)/,"").
				gsub(/[a-z0-9._-]+@[a-z0-9._-]+\.[a-z]{2,3}\b/i,"").
				gsub(/(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}/,"").
				gsub(/twitter:.+/i,""))
                # Convert date to something readable
				datetime = Time.at(message.date).to_datetime
				date = datetime.to_s.scan(/\d{4}-\d{2}-\d{2}/)
				time = datetime.to_s.scan(/\d{2}:\d{2}:\d{2}/)
				if contact == nil or contact == ""
					_pictures.push("NotFound.png")
					_names.push("Not Found" + " on " + date[0] + " at " + time[0])
				else
                    # If there's a contact, pass picture information, name and date and time of message				
					_pictures.push(contact.id + ".png")
					_names.push(contact.given_name + " " + contact.surname + " on " + date[0] + " at " + time[0])
				end
			}
		_thread.push(_messages)
		_thread.push(_pictures)
		_thread.push(_names)
		_threads.push(_thread)
		end
	}
	
    # Call the page and display threads	
	erb :main, :layout => :layout, :locals => {:threads => _threads}
end
