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
        retval.push record[attribute.to_i]
      end
      return retval
    end

  end

end
