module Sgm::Membership

  class Base

    def process
      STDERR.puts "#{self.class}.process: not implemented"
      return -1
    end
    
  end

  Dir["#{$app_path}/lib/membership/*.rb"].each do |path|
    require_relative path
  end

end
