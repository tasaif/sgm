before "/api/*" do
  request.env['CONTENT_TYPE'] ||= 'application/xml'
end

after "*" do
  response.write("\n")
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
    record = klass.where(id: params["id"]).first
    _method = params['method']&.to_sym
    if record.nil?
      status 404
    else
      if !_method.nil?
        JSON.pretty_generate(record.send(_method))
      else
        if request.env['CONTENT_TYPE'] == 'application/xml'
          record.to_xml.to_s
        else
          record.to_json
        end
      end
    end
  end

end

post '/api/group' do
  doc = Nokogiri::XML.parse(request.body.read.strip)
  case doc.root.name
  when "groups"
    Sgm::Group.static_process_groups(doc.xpath('/groups/group').to_a)
  when "group"
    Sgm::Group.static_process_groups(doc.children)
  else
    status 400
  end

  "ok"
  #if request.env['CONTENT_TYPE'] == 'application/xml'
  #  group.to_xml.to_s
  #else
  #  group.to_json
  #end
end

get '/debug' do
  binding.pry
end

get '/debug/reset' do
  count = 0
  get_sequel_models.each do |klass|
    next if klass == Sgm::Directory::Config
    next if klass.to_s.start_with? '#<Class' # These are the inherited Server classes
    klass.each do |instance|
      instance.destroy
      count += 1
    end
  end
  "Deleted #{count} records"
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
