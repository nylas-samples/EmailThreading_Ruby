# frozen_string_literal: true

# Import your dependencies
require 'dotenv/load'
require 'nylas'
require 'sinatra'
require 'nokogiri'
require 'date'
require 'open-uri'

# Initialize Nylas client
nylas = Nylas::Client.new(
  api_key: ENV['V3_TOKEN']
)

main_thread = Data.define(:thread, :message, :picture, :names)
data_threads = []
all_threads = []

# Use the Nokogiri gem to clean up the email response
def clean_content(raw_html)
  html = raw_html.encode('UTF-8', invalid: :replace, undef: :replace,
                                  replace: '', universal_newline: true).gsub(/\P{ASCII}/, '')
  parser = Nokogiri::HTML(html, nil, Encoding::UTF_8.to_s)
  parser.xpath('//script')&.remove
  parser.xpath('//style')&.remove
  parser.xpath('//text()').map(&:text).join('<br> ')
end

# Get the contact associated to the email address
def get_contact(nylas, email)
  query_params = {
    email: email
  }

  contacts, = nylas.contacts.list(identifier: ENV['GRANT_ID'],
                                  query_params: query_params)
  contacts.each do |contact|
    return contact
  end
end

# Download the contact picture if it's not stored already
def download_contact_picture(_nylas, contact)
  return unless contact[:id] != ''

  file_name = "public/#{contact[:given_name]}_#{contact[:surname]}.png"
  # Read the image and download it
  URI.parse(contact[:picture_url]).open do |image|
    File.open(file_name, 'wb') do |file|
      file.write(image.read)
    end
  end
end

# When calling the application for the first time
get '/' do
  all_threads = []
  # Call the page
  erb :main, layout: :layout, locals: { threads: all_threads }
end

# When asking for the email threading
post '/search' do
  # Get parameter from form
  search = params[:search]

  query_params = {
    search_query_native: "from: #{search}"
  }

  # Search all threads related to the email address
  threads, = nylas.threads.list(identifier: ENV['GRANT_ID'],
                                query_params: query_params)

  all_threads = []

  # Loop through all the threads
  threads.each do |thread|
    new_thread = main_thread.new('', '', '', '')
    # Look for threads with more than 1 message
    next unless thread[:message_ids].length > 1

    # Get the subject of the first email
    new_thread = new_thread.with(thread: thread[:subject])
    # Loop through all messages contained in the thread
    thread[:message_ids].each do |message|
      # Get information from the message
      message, = nylas.messages.find(identifier: ENV['GRANT_ID'],
                                     message_id: message)
      # Try to get the contact information
      contact = get_contact(nylas, message[:from][0][:email])
      if contact.length.positive?
        # If the contact is available, downloads its profile picture
        download_contact_picture(nylas, contact)
      end
      # Remove extra information from the message like appended message,
      # email and phone number
      new_thread = new_thread.with(message: clean_content(message[:body])
      .gsub(/(\bOn.*\b)(?!.*\1)/, '')
      .gsub(/[a-z0-9._-]+@[a-z0-9._-]+\.[a-z]{2,3}\b/i, '')
      .gsub(/(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}/, '')
      .gsub(/twitter:.+/i, ''))
      # Convert date to something readable
      datetime = Time.at(message[:date]).to_datetime
      date = datetime.to_s.scan(/\d{4}-\d{2}-\d{2}/)
      time = datetime.to_s.scan(/\d{2}:\d{2}:\d{2}/)
      if contact.empty?
        new_thread = new_thread.with(picture: 'NotFound.png',
                                     names: "Not Found on #{date[0]} at #{time[0]}")
      else
        # If there's a contact, pass picture information, name and date and time of message
        new_thread = new_thread.with(picture: "#{contact[:given_name]}_#{contact[:surname]}.png",
                                     names: "#{contact[:given_name]} #{contact[:surname]} on #{date[0]} at #{time[0]}")
      end
      data_threads.push(new_thread)
    end
    all_threads.push(data_threads)
    data_threads = []
  end

  # Call the page and display threads
  erb :main, layout: :layout, locals: { threads: all_threads }
end
