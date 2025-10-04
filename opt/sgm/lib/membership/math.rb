module Sgm::Membership

  class Math < Base

    def parse_operand(text)
      l, val = text[1..-2].split(':')
      option = l.match(/\[(.*)\]/)
      tag = l.split('[').first
      case tag
      when 'group'
        if option.nil?
          group = Sgm::Group.where(id: val).first
          return nil if group.nil?
          return Sgm::Member.where(group_id: group.id).map {|el| el[:member_id]}
        else
          k, v = option[1].split('=', 2)
          _v = v.delete_prefix("'").delete_suffix("'")
          case k
          when 'directory-id'
            members = Sgm::Directory::Server.all[_v].get_members(val)
            return members
          end
        end
      when 'user'
        return [val]
      end
      return eval(text)
    end

    def process
      text = doc.text
      operator = nil
      lhs_operand = nil
      c = nil
      i = 0
      l_parens_indices = []
      known_operators = ['+', '-']
      loop do
        c = text[i]
        if known_operators.include? c
          operator = c
        end
        case c
        when '('
          l_parens_indices.push i
        when ')'
          l = l_parens_indices.pop
          r = i
          operand = parse_operand(text[l..r])
          return nil if operand.nil?
          replaced_text = text[l..r]
          text[l..r] = operand.to_s
          i = i - replaced_text.length + operand.to_s.length
        end
        i += 1
        break if i >= text.length
      end
      members = eval(text)
      members.each do |member|
        Sgm::Member.find_or_create(group_id: group_id, member_id: member)
      end
    end

  end

end
