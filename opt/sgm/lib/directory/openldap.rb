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

    #
    # Note: This only returns DNs that exist
    #
    def get_members(group_dn)
      retval = []
      treebase = group_dn
      members = []
      members = @connection.search(base: treebase, attributes: ["member"])&.entries&.first&.member || []
      attribute = @options.css('user-unique-attribute').text
      members.each do |member|
        @connection.search(base: member, attributes: [attribute, 'objectclass']) do |entry|
          if entry.objectclass.include? 'groupOfNames'
            retval += get_members(entry.dn)
          else
            retval.push entry.instance_variable_get('@myhash')[attribute.to_sym].first
          end
        end
      end
      return retval
    end

    def select_valid_members(members)
      attr = @options.css('user-unique-attribute').text
      treebase = @options.css('users-base').text
      filter = "(|#{members.map {|el| "(#{attr}=#{el.member_id})"}.join})"
      @connection.search(base: treebase, filter: filter, attributes: [attr]).map {|result| result[attr].first }
    end

    def group_exists?(group_directory_id)
      (@connection.search(base: group_directory_id) || []).count > 0
    end

    def add_members(group_directory_id, members)
      _members = members - get_members(group_directory_id)
      if _members.count == 0
        puts "Additive: Noop adding members to '#{group_directory_id}'"
        return
      end
      dns = get_member_dns(_members)
      group_cn = group_directory_id.downcase.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last
      if group_exists?(group_directory_id)
        @connection.add_attribute(group_directory_id, :member, dns)
      else
        @connection.add(dn: group_directory_id, attributes: {cn: group_cn, objectClass: 'groupOfNames', member: dns})
      end
    end

    def sync_members(group_directory_id, members)
      member_dns = get_member_dns(members)
      attr = @options.css('user-unique-attribute').text
      group_cn = group_directory_id.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last
      if members.count == 0 && group_exists?(group_directory_id)
        @connection.delete(group_directory_id)
      elsif !group_exists?(group_directory_id)
        @connection.add(dn: group_directory_id, attributes: {cn: group_cn, objectClass: 'groupOfNames', member: member_dns})
      else
        existing_member_dns = @connection.search(base: group_directory_id, attributes: [:member]).first.member
        members_to_add = member_dns - existing_member_dns
        members_to_remove = existing_member_dns - member_dns
        if members_to_add.count > 0
          @connection.add_attribute(group_directory_id, :member, members_to_add)
        else
          puts "Sync: No members to add for '#{group_directory_id}'"
        end
        if members_to_remove.count > 0
          @connection.modify(dn: group_directory_id, operations: [[:delete, :member, members_to_remove]])
        else
          puts "Sync: No members to remove for '#{group_directory_id}'"
        end
      end
    end

    def get_member_dns(members)
      attr = @options.css('user-unique-attribute').text
      treebase = @options.css('users-base').text
      filter = "(|#{members.map {|el| "(#{attr}=#{el})"}.join})"
      @connection.search(base: treebase, filter: filter, attributes: [attr]).map {|result| result[:dn].first }
    end

  end

end
