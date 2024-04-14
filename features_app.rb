# frozen_string_literal: true
require 'sinatra'
require 'net/http'
require 'pg'

set :port, 3000

def get_features
  feature_uri = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.geojson'
  uri = URI(feature_uri)
  res = Net::HTTP.get_response(uri)
  if res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    formated_features = []
    json['features'].each { |feature|
      mag = feature['properties']['mag'].to_f.between?(-1.0, 10.0) ? feature['properties']['mag'].to_f : nil
      coordinates_long = feature['geometry']['coordinates'][0].to_f.between?(-180.0, 180.0) ? feature['geometry']['coordinates'][0].to_f : nil
      coordinates_lat = feature['geometry']['coordinates'][1].to_f.between?(-90.0, 90.0) ? feature['geometry']['coordinates'][1].to_f : nil
      title = feature['properties']['title']
      url = feature['properties']['url']
      place = feature['properties']['place']
      mag_type = feature['properties']['magType']
      id = feature['id']
      time = feature['properties']['time']
      tsunami = feature['properties']['tsunami'] == 0 ? false : true
      if mag.nil? || title.nil? || url.nil? || place.nil? || mag_type.nil? || coordinates_long.nil? || coordinates_lat.nil?
        next
      end
      formated_features.append({ id: id, mag: mag, time: time, tsunami: tsunami, title: title, url: url, place: place, mag_type: mag_type, longitude: coordinates_long, latitude: coordinates_lat })
    }
  else
    "Something went wrong"
  end
  formated_features
end

def get_db_connection
  # Connection details
  host = ENV["PG_HOST"] ? ENV.has_key?("PG_HOST") : "localhost"
  port = ENV["PG_PORT"] ? ENV.has_key?("PG_PORT") : 5432
  dbname = ENV["PG_DB"] ? ENV.has_key?("PG_DB") : "earthquake"
  user = ENV["PG_USER"] ? ENV.has_key?("PG_USER") : "postgres"
  password = ENV["PG_PASS"] ? ENV.has_key?("PG_PASS") : "postgres"
  PG::Connection.new(host: host, port: port, dbname: dbname, user: user, password: password)
end

def save_feature(features, db_connection)
  features.each do |feature|
    puts feature
    begin
      sql = "INSERT INTO public.features (external_id,magnitude,time,tsunami,title,url,place,magtype,longitude,latitude) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)"
      db_connection.exec_params(sql, feature.values)
    rescue PG::UniqueViolation => e
      puts "This feature already exists, so continue. ---> #{e}"
      next
    rescue Exception => e
      puts "Something went wrong. ---> #{e}"
      db_connection.close if db_connection
    end
  end
  db_connection.close if db_connection
end

get '/' do
  first_name = 'Hector'
  last_name = 'Guerrero'
  "#{first_name} #{last_name} - Frogmi"
end

get '/features' do
  erb :index
end

get '/comments' do
  erb :comments
end

# http://127.0.0.1:3000/api/features?page=1&per_page=2%27
# http://127.0.0.1:3000/api/features?page=1&per_page=2&mag_type%5B%5D=md%27
get '/api/features' do
  sort_field = params['sort_field'].nil? ? "id" : params['sort_field']
  page = params['page'].nil? ? 1 : params['page'].to_i
  per_page = params['per_page'].nil? ? 5 : params['per_page'].to_i
  mag_type_types = %w[md ml ms mw me mi mb mlg]
  mag_type = params['mag_type'].nil? ? nil : params['mag_type']
  unless mag_type_types.include?(mag_type)
    mag_type = nil
  end
  conn = get_db_connection
  # Calculate offset based on page number and items per page
  offset = (page - 1) * per_page
  table_name = "public.features"
  if mag_type.nil?
    # sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
    #                 AS numbered_data WHERE row_num BETWEEN $2 AND $3"
    print("#{offset + 1} #{offset + per_page}")
    sql = "SELECT * FROM #{table_name}
           ORDER BY $1 ASC
           OFFSET $2 -- page
           LIMIT $3  -- per-page"
    results = conn.exec_params(sql, [sort_field, offset, per_page])
    total_sql = "SELECT * FROM #{table_name}"
    result_sql = conn.exec(total_sql)
  else
    # sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
    #                AS numbered_data WHERE magtype=$2 AND row_num BETWEEN $3 AND $4"
    sql = "SELECT * FROM #{table_name}
           WHERE magtype = $1
           ORDER BY $2 ASC
           OFFSET $3 -- page
           LIMIT $4  -- per-page
           "
    results = conn.exec_params(sql, [mag_type, sort_field, offset, per_page])
    # total_sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
    #                 AS numbered_data WHERE magtype=$2"
    total_sql = "SELECT * FROM #{table_name} WHERE magtype = $1"
    result_sql = conn.exec_params(total_sql, [mag_type])
  end
  data = []
  total_pages = (result_sql.ntuples / per_page.to_f).ceil
  results.each_row do |row|
    json_row = {
      id: "#{row[1]}",
      type: "feature",
      attributes: {
        external_id: "#{row[0]}",
        magnitude: "#{row[2]}",
        place: "#{row[3]}",
        time: "#{row[4]}",
        tsunami: "#{row[5]}",
        mag_type: "#{row[6]}",
        title: "#{row[7]}",
        coordinates: {
          longitude: "#{row[8]}",
          latitude: "#{row[9]}"
        }
      },
      links: {
        external_url: "#{row[10]}",
      }
    }
    data.append(json_row)
  end
  all_together = { data: data, pagination: { current_page: "#{page}", total: "#{total_pages}", per_page: "#{per_page}" } }
  content_type :json
  all_together.to_json
end

# http://127.0.0.1:3000/api/features/1/comments
post '/api/features/:id/comments' do
  require 'json'
  begin
    payload = JSON.parse(request.body.read)
    print payload
    raise JSON::ParserError, "Body parameter is empty" if payload["body"].nil? || payload["body"].empty?
    comment = payload["body"]
    id = params[:id]
    # validating if feature exist
    conn = get_db_connection
    sql = "SELECT COUNT(*) FROM public.features WHERE id = #{id}"
    if conn.exec(sql)[0]['count'].to_i == 0
      conn.close
      status 404
      { message: 'Feature does not exist.', status: 404 }.to_json
    else
      sql = "INSERT INTO public.comments (text,feauture_id) VALUES ($1, $2)"
      result = conn.exec_params(sql, [comment, id])
      if result.res_status == 'PGRES_COMMAND_OK'
        conn.close
        status 200
        { message: 'comment was saved into the database.', status: 200 }.to_json
      end
    end
  rescue JSON::ParserError => e
    status 400
    print e
    { message: 'Bad request! Missing/Empty Body.', status: 400 }.to_json
  end
end

# features = get_features
# db_connection = get_db_connection
# save_feature(features, db_connection)
