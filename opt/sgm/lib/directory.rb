module Sgm::Directory

  class Server
    attr_accessor :options

    @all = {}

    def initialize(options={})
      @options = options
      $logger.debug("Connecting to #{@options.attr('id')}")
      connect
      $logger.debug("Connected to #{@options.attr('id')} and found #{groups.count} groups")
      Server.all[options['id']] = self
    end

    class << self
      attr_accessor :all
    end

  end

  Dir["#{$app_path}/lib/directory/*.rb"].each do |path|
    require_relative path
  end

  def self._load(directory)
    config = Config.find_or_create(id: directory['id'], xml_data: directory.to_xml)
    klass = Object.const_get("Sgm::Directory::#{directory['type']}::Server")
    klass.new(directory)
    config.instance
  end

  def self.load_from_config
    $config.css('directory').each do |directory|
      _load(directory)
    end
  end

  def self.add(type, id, options)
    xml_text = "<directory id='#{id}' type='#{type}'>"
    options.each do |k, v|
      _k = k.to_s.gsub('_', '-')
      xml_text += "<#{_k}>#{v}</#{_k}>"
    end
    xml_text += "</directory>"
    directory = Nokogiri::XML.parse(xml_text).xpath('/directory').first
    _load(directory)
  end

  load_from_config unless $config.nil?

end
