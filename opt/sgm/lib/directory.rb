module Sgm::Directory

  class Server
    attr_accessor :options

    @all = {}

    def initialize(options={})
      @options = options
      print "#{@options.attr('id')} connecting...  "
      connect
      puts "\tGroups: #{groups.count}"
      Server.all[options['id']] = self
    end

    class << self
      attr_accessor :all
    end

  end

  Dir["#{$app_path}/lib/directory/*.rb"].each do |path|
    require_relative path
  end

  $config.css('directory').each do |directory|
    config = Config.find_or_create(id: directory['id'], xml_data: directory.to_xml)
    klass = Object.const_get("Sgm::Directory::#{directory['type']}::Server")
    klass.new(directory)
    config.instance
  end

end
