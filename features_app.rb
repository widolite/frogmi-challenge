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
    print feature
    puts ""
    print feature.values
    begin
      sql = "INSERT INTO public.features (external_id,magnitude,time,tsunami,title,url,place,magtype,longitude,latitude) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)"
      db_connection.exec_params(sql, feature.values)
    rescue PG::UniqueViolation => e
      puts "This feature already exists so continue. ---> #{e}"
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

# http://127.0.0.1:3000/api/features?page=1&per_page=2%27
# http://127.0.0.1:3000/api/features?page=1&per_page=2&mag_type%5B%5D=md%27
get '/api/features' do
  sort_field = params['sort_field'].nil? ? "id" : params['sort_field']
  page = params['page'].nil? ? 1 : params['page'].to_i
  per_page = params['per_page'].nil? ? 5 : params['per_page'].to_i
  mag_type_types = ['md', 'ml', 'ms', 'mw', 'me', 'mi', 'mb', 'mlg']
  mag_type = params['mag_type'].nil? ? nil : params['mag_type']
  if !mag_type_types.include?(mag_type)
    mag_type = nil
  end
  conn = get_db_connection
  # Calculate offset based on page number and items per page
  offset = (page - 1) * per_page
  table_name = "public.features"
  if mag_type.nil?
    sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
                    AS numbered_data WHERE row_num BETWEEN $2 AND $3"
    results = conn.exec_params(sql, [sort_field, offset + 1, offset + per_page])
    total_sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
                    AS numbered_data"
    result_sql = conn.exec_params(total_sql, [sort_field])
  else
    sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
                    AS numbered_data WHERE magtype=$2 AND row_num BETWEEN $3 AND $4"
    results = conn.exec_params(sql, [sort_field, mag_type, offset + 1, offset + per_page])
    total_sql = "SELECT * FROM (SELECT *, ROW_NUMBER() OVER (ORDER BY $1 ) AS row_num FROM #{table_name})
                    AS numbered_data WHERE magtype=$2"
    result_sql = conn.exec_params(total_sql, [sort_field,mag_type])

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

# features = get_features
# db_connection = get_db_connection
# save_feature(features, db_connection)
