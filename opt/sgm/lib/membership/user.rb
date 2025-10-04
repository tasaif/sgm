module Sgm::Membership

  class User < Base

    def process
      Sgm::Member.find_or_create(member_id: doc.text, group_id: group_id)
    end

  end

end
