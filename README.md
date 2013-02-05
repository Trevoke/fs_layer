# Cabinet

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'cabinet'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cabinet

## Usage

    Cabinet.retrieve file
    Cabinet.insert file
    Cabinet.delete file
    Cabinet.config do |c|
      c.fake = true
      c.log = true
      c.logger = Logger.new
    end
    Cabinet.link('file').to('symlink_destination')

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### possible vocabulary

* file / folder
* hanging file
* shredder
* recycle bin
* marker
* reference
* index
* label
* lock
