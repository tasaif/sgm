require 'net/ldap'

module Sgm::Directory::OpenLDAP

  class Server < Sgm::Directory::Server

    def connect
      pattern = %r{\A(?:(?<protocol>[a-zA-Z][a-zA-Z0-9+\-.]*)://)?(?<host>[^:/]+)(?::(?<port>\d+))?\z}
      connection_details = @options.css('uri').text.match(pattern)
      match, protocol, host, port = connection_details.to_a
      default_port = 389
      default_port = 636 if (protocol || "").include? 'ldaps'
      @connection = Net::LDAP.new
      @connection.host = host
      @connection.port = (port || default_port).to_i
      @connection.auth @options.css('username').text, @options.css('password').text
      if @connection.bind
        puts "ok"
      else
        binding.pry
        throw "directory connection failed"
      end

    end

    def groups
      retval = []
      filter = Net::LDAP::Filter.eq( "objectClass", "groupOfNames" )
      treebase = @options.css('groups-base').text
      @connection.search(base: treebase, filter: filter, attributes: ["member"]) do |entry|
        entry.each do |attribute, values|
          next unless attribute == :dn
          retval.push values
        end
      end
      return retval.inject(:+) || []
    end

    def get_members(group_dn)
      retval = []
      #filter = "(&(objectClass=groupOfNames)(dn=#{group_dn}))"
      #treebase = @options.css('groups-base').text
      treebase = group_dn
      members = []
      @connection.search(base: treebase, attributes: ["member"]) do |entry|
        members += entry.instance_variable_get('@myhash')[:member]
      end
      attribute = @options.css('user-unique-attribute').text
      members.each do |member|
        @connection.search(base: member, attributes: [attribute]) do |entry|
          retval += entry.instance_variable_get('@myhash')[attribute.to_sym]
        end
      end
      return retval
    end

  end

end
