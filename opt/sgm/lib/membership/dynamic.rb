module Sgm::Membership

  class Dynamic < Base

    def process
      doc.xpath('/*/*').each do |el_membership|
        result = Sgm::Group.static_process(self, el_membership)
      end
    end

  end

end
