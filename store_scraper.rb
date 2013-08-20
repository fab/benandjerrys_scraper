require 'mechanize'
require 'csv'

a = Mechanize.new
page = a.get('http://m.benjerry.com/flavor-locator')
flavor_form = page.forms.first

stores_array = []

# ************** RUN ALL THE US ZIP CODES ********************

zip_codes = []

CSV.foreach('zip_codes.csv') do |csv|
  zip_codes << csv.first.to_i
end

# ******************* OR SET YOUR OWN ************************

# eg: zip_codes = [94102, 94103, 94104, 94105, 94107, 94108]

zip_codes.each do |zip_code|
  flavor_form.locatorZip = zip_code
  puts "Scraping stores for zip code: #{zip_code}"

  selectlist = flavor_form.field_with(:name => "locatorFlavor_r")

  flavor_options = selectlist.options
  flavor_options[5..-19].each do |flavor_option|
    selectlist.value = flavor_option.value
    flavor_name = flavor_option.text.slice(/(?<=- ).*/)
    puts "Now scraping data for: #{flavor_name}"

    page = a.submit(flavor_form)

    page.links.each_with_index do |link, index|
        break if link.href == nil
        if link.href.include?('google')
          store_details = link.text.strip.gsub("\r\n", '').squeeze("\t").split("\t")
          name = store_details.first
          street = store_details[1]
          city = store_details[2].slice(/\D+/)[0..-2]
          zip = store_details[2].slice(/\d+/)
          stores_array << [name, "#{street}, #{city} #{zip}", flavor_name]
        end
    end
  end
end

uniq_stores = Hash.new { |hash, key| hash[key] = []}
stores_array.each do |store|
  uniq_stores[store[0..1]] << store[-1]
end

uniq_stores.each do |k, v|
  uniq_stores[k].uniq!
end

CSV.open("bandj_stores.csv", "wb") do |csv|
  csv << ['name', 'address', 'flavors']
  uniq_stores.each do |store, flavors|
    flavor_list = flavors.join(', ')
    csv << [store[0], store[1], flavor_list]
  end
end



