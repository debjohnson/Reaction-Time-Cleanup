# encoding: UTF-8
require 'csv'
require 'iconv'

class Array
  def avg(params)
    key = params[:key]
    exclude = params[:exclude] || nil

    size = self.size
    sum = self.inject(0) {|mem, s| s[key] + mem}
    sum.to_f/size
  end
  
  def stadev(params)
    key = params[:key]
    exclude = params[:exclude] || nil

    avg = self.avg(params)
    size = self.size
    sum_of_sqrs = self.inject(0) { |mem, s| mem + ((s[key] - avg) ** 2) unless exclude }
    Math.sqrt(sum_of_sqrs/(self.size - 1))
  end
end

dir_string = "/Users/Deb/Desktop/Tab/SJ_5221"
file_dir = Dir.new(dir_string)

# files = ARGV[0].split(',')[1..-1] || []
files = []
Dir.foreach(dir_string) do |file|
  files << file if file.size > 2
end

first_file = files[0]

file_name = File.basename(first_file).split(".")[0]
path = dir_string
# path = "/Users/Matt/Dropbox/Matt and Debs Stuff!/Raw Training Data/VJ_5226"

path = Pathname.new(path)

subject_id = file_name.split("_")[0..1].join("_")

output_file = "#{path.parent}/#{subject_id}_Summary.csv"

output_avgs = {}

files.each do |file|
  ver_num = file.split('.')[0].match(/_[a-zA-Z]+(\d*)/)[1].to_i

  text = File.read((path + file).to_s)
  ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
  valid_string = ic.iconv(text + ' ')[0..-2]

  # data = CSV.foreach(valid_string, {
  #   :col_sep => "\t",
  #   :row_sep => :auto
  # })

  string = valid_string.split("\r")
  data = []

  string.each do |line|
    data << line
  end

  data.map! { |row| row.split("\t") }

  data.shift

  headers = data.shift
  rows = data

  family = []
  individual = []

  rows.each do |row|
    category = row[headers.index("Category").to_i]
    match = row[headers.index("Match").to_i]
    accuracy = row[headers.index("Stim.ACC").to_i].to_i
    response_time = row[headers.index("Stim.RT").to_i].to_i

    if response_time != 0
      if category =~ /[iI]ndividual/
        individual << {:match => match, :accuracy => accuracy, :response_time => response_time}
      else
        family << {:match => match, :accuracy => accuracy, :response_time => response_time}
      end
    end
  end

  individual.delete_if { |i| i[:match] =~ /[mM]ismatch/ }
  family.delete_if { |f| f[:match] =~ /[mM]ismatch/ }
  individual.delete_if { |i| i[:accuracy] == 0 }
  family.delete_if { |f| f[:accuracy] == 0 }
  
  output_avgs[ver_num] = {:irt => '', :frt => ''}

  if individual.size < 2
    output_avgs[ver_num][:irt] = 'NA'
  else
    indiv_avg = individual.avg(:key => :response_time)
    indiv_stdev = individual.stadev(:key => :response_time) * 2
    individual.delete_if { |i| (i[:response_time] - indiv_avg).abs > indiv_stdev }
    output_avgs[ver_num][:irt] = individual.avg(:key => :response_time)
  end
  
  if family.size < 2
    output_avgs[ver_num][:frt] = 'NA'
  else
    fam_avg = family.avg(:key => :response_time)
    fam_stdev = family.stadev(:key => :response_time) * 2
    family.delete_if { |f| (f[:response_time] - fam_avg).abs > fam_stdev }    
    output_avgs[ver_num][:frt] = family.avg(:key => :response_time)
  end
end

output = [',Family,Individual']

files.each do |file|
  ver_num = file.split('.')[0].match(/_[a-zA-Z]+(\d*)/)[1].to_i
  oan = output_avgs[ver_num]
  output << "#{ver_num},#{oan[:frt]},#{oan[:irt]}"
end

File.open(output_file, 'w') do |o|
  o.puts output.join("\n")
end



