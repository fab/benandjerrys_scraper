require 'Mechanize'
require 'CSV'

def setup
  @agent = Mechanize.new
  @page = @agent.get('http://m.benjerry.com/flavor-locator')
  @flavor_form = @page.forms.first
  @stores_array = []
end

def create_zip_code_array(filename)
  zip_codes = []
  CSV.foreach(filename) do |csv|
    zip_codes << csv.first.to_i
  end
  zip_codes
end

def store_entry?(link)
  link.href.include?('google')
end

def iterate_over_links(page, flavor_name)
  page.links.each_with_index do |link, index|
    break if link.href == nil
    if store_entry?(link)
      store_details = link.text.strip.gsub("\r\n", '').squeeze("\t").split("\t")
      push_entry_into_stores_array(store_details, flavor_name)
    end
  end
end

def push_entry_into_stores_array(store_details, flavor_name)
  name = store_details.first
  street = store_details[1]
  city = store_details[2].slice(/\D+/)[0..-2]
  zip = store_details[2].slice(/\d+/)
  @stores_array << [name, "#{street}, #{city} #{zip}", flavor_name]
end

def iterate_over_flavors(flavor_options)
  flavor_options[5..-19].each do |flavor_option|
    @selectlist.value = flavor_option.value
    flavor_name = flavor_option.text.slice(/(?<=- ).*/)
    puts "Now scraping data for: #{flavor_name}"
    page = @agent.submit(@flavor_form)
    iterate_over_links(page, flavor_name)
  end
end

def iterate_over_zip_codes(zip_codes)
  total_zip_codes = zip_codes.length
  zip_codes.each_with_index do |zip_code, index|
    @flavor_form.locatorZip = zip_code
    puts "Scraping stores for zip code (#{index + 1}/#{total_zip_codes}): #{zip_code}"
    @selectlist = @flavor_form.field_with(:name => "locatorFlavor_r")
    flavor_options = @selectlist.options
    iterate_over_flavors(flavor_options)
  end
end

def create_unique_stores_hash
  uniq_stores = Hash.new { |hash, key| hash[key] = []}
  @stores_array.each do |store|
    uniq_stores[store[0..1]] << store[-1]
  end
  uniq_stores
end

def ensure_unique_flavors(uniq_stores)
  uniq_stores.each do |k, v|
    uniq_stores[k].uniq!
  end
end

def export_uniq_stores_hash_to_csv(new_filename, uniq_stores)
  CSV.open(new_filename, "wb") do |csv|
    csv << ['name', 'address', 'flavors']
    uniq_stores.each do |store, flavors|
      flavor_list = flavors.join(', ')
      csv << [store[0], store[1], flavor_list]
    end
  end
end

def run_scraper(zip_codes_filename, output_filename)
  setup
  zip_codes = create_zip_code_array(zip_codes_filename)
  iterate_over_zip_codes(zip_codes)
  uniq_stores = create_unique_stores_hash
  ensure_unique_flavors(uniq_stores)
  export_uniq_stores_hash_to_csv(output_filename, uniq_stores)
end


# JUST EDIT THE LINE BELOW WITH YOUR INPUT AND OUTPUT CSV FILENAMES

run_scraper('bay_area_zip_codes.csv', 'all_bay_area_stores.csv')
