before "/api/*" do
  request.env['CONTENT_TYPE'] ||= 'application/xml'
end

get_sequel_models.each do |klass|

  get "/api/#{klass.table_name.to_s.pluralize}" do
    if request.env['CONTENT_TYPE'] == 'application/xml'
      klass.to_xml.to_s
    else
      klass.all.to_json
    end
  end

  get "/api/#{klass.table_name}/:id" do
    retval = klass.where(id: params["id"]).first
    if retval.nil?
      status 404
    else
      if request.env['CONTENT_TYPE'] == 'application/xml'
        retval.to_xml.to_s
      else
        retval.to_json
      end
    end
  end

end

get '/debug' do
  binding.pry
end

=begin
get '/api/group' do
  Sgm::Group.map {|g| g.id }.sort.to_json
end

get '/api/group/:id' do
  Sgm::Member.where(group_id: params['id']).map {|el| el.member_id}.sort.to_json
end

get '/api/member' do
  Sgm::Member.map {|el| el.member_id}.uniq.sort.to_json
end

get '/api/member/:id' do
  Sgm::Member.where(member_id: params['id']).map {|el| el.group_id}.uniq.sort.to_json
end
=end
