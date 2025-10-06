require 'net/ssh'

module Sgm::Directory::POSIX

  class Server < Sgm::Directory::Server

    def connect
      pattern = %r{\A(?:(?<protocol>[a-zA-Z][a-zA-Z0-9+\-.]*)://)?(?<host>[^:/]+)(?::(?<port>\d+))?\z}
      connection_details = @options.css('uri').text.match(pattern)
      match, protocol, host, port = connection_details.to_a
      default_port = 22
      @connection = Net::SSH.start(host, @options.css('username').text, password: @options.css('password').text, port: (port || default_port))
      if @connection.exec!("echo test").strip == "test"
        puts "ok"
      else
        throw "POSIX connection failed"
      end

    end

    def groups
      @connection.exec!("cat /etc/group").split("\n")
    end

    def get_members(group)
      retval = []
      record = @connection.exec!('cat /etc/group').split.map {|line| line.split(":")}.select {|record| record[0] == group}.first
      members = record.last.split(',')
      passwd = @connection.exec!('cat /etc/passwd').split.map {|line| line.split(":")}
      attribute = @options.css('user-unique-attribute').text
      members.each do |member|
        record = passwd.select {|record| record[0] == member}.first
        next if record.nil?
        retval.push record[attribute.to_i]
      end
      return retval
    end

    def group_exists?(group_directory_id)
      @connection.exec!('cat /etc/group').split.map {|line| line.split(":")}.select {|record| record[0] == group_directory_id}.count > 0
    end

    def select_valid_members(members)
      users = @connection.exec!('cat /etc/passwd').split.map {|line| line.split(":").first}
      members
        .map {|el| el.member_id}
        .select {|member| users.include?(member)}
    end

    def ensure_group(group_directory_id)
      unless group_exists? group_directory_id
        @connection.exec!("sudo groupadd '#{group_directory_id}'")
      end
    end

    def add_members(group_directory_id, members)
      ensure_group group_directory_id
      _members = members - get_members(group_directory_id)
      if _members.count == 0
        puts "Additive: Noop adding members to '#{group_directory_id}'"
        return
      end
      _members.each do |_member|
        @connection.exec!("sudo usermod -aG '#{group_directory_id}' '#{_member}'")
      end
    end

    def sync_members(group_directory_id, members)
      ensure_group group_directory_id
      existing_members = get_members(group_directory_id)
      members_to_add = members - existing_members
      members_to_remove = existing_members - members
      members_to_add.each do |member|
        @connection.exec!("sudo usermod -aG '#{group_directory_id}' '#{member}'")
      end
      members_to_remove.each do |member|
        @connection.exec!("sudo usermod -rG '#{group_directory_id}' '#{member}'")
      end
    end

  end

end
