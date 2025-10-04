require_relative 'openldap'

module Sgm::Directory::ActiveDirectory

  class Server < Sgm::Directory::OpenLDAP::Server

    def groups
      retval = []
      filter = Net::LDAP::Filter.eq( "objectClass", "group" )
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
      filter = "(&(objectClass=user)(memberOf=#{group_dn}))"
      treebase = @options.css('users-base').text
      attribute = @options.css('user-unique-attribute').text
      @connection.search(base: treebase, filter: filter, attributes: [attribute]) do |entry|
        entry.each do |_attribute, _values|
          next unless _attribute == attribute.downcase.to_sym
          retval.push _values
        end
      end
      return retval.inject(:+) || []
    end

  end

end
