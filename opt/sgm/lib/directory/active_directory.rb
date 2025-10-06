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

    def ensure_group(group_directory_id)
      return if group_exists? group_directory_id
      group_cn = group_directory_id.downcase.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last
      @connection.add(dn: group_directory_id, attributes: {cn: group_cn, samaccountname: group_cn, objectClass: 'group'})
    end

    def add_members(group_directory_id, members)
      ensure_group(group_directory_id)
      super
    end

    def sync_members(group_directory_id, members)
      ensure_group(group_directory_id)
      member_dns = get_member_dns(members)
      attr = @options.css('user-unique-attribute').text
      group_cn = group_directory_id.downcase.split(',').select {|el| el.start_with? 'cn='}.first.split('=').last

      existing_member_dns = @connection.search(base: group_directory_id, attributes: [:member]).first.instance_variable_get('@myhash')[:member] || []
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

end
