# Email Threading

This project will show you how to group emails threads using Ruby and Nylas.

## Setup

### System dependencies

- Ruby 3.2.2 or greater

### Gather environment variables

You'll need the following values:

```text
V3_TOKEN = ""
GRANT_ID = ""
```

Add the above values to a new `.env` file:

```bash
$ touch .env # Then add your env variables
```

### Install dependencies

```bash
$ gem install dotenv
$ gem install sinatra
$ gem install sinatra-base
$ gem install sinatra-contrib
$ gem install nokogiri
$ gem install nylas
$ gem install puma
```

## Usage

Clone the repository. Go to your terminal and type:

```bash
$ ruby EmailThreading.rb
```

And go to `http://localhost:4567`

Enter an email and you will see an accordion showing the email threads shared with that email.
