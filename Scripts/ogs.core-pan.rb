#!/usr/bin/env ruby

#
# @author: Luis M. Rodriguez-R
# @update: Aug-31-2015
# @license: artistic license 2.0
#

$:.push File.expand_path(File.dirname(__FILE__) + '/lib')
require 'enveomics_rb/og'
require 'optparse'
require 'json'

o = {q:false, a:false, n:10}
ARGV << '-h' if ARGV.size==0
OptionParser.new do |opts|
   opts.banner = "
Subsamples the genomes in a set of Orthology Groups (OGs) and estimates the
trend of core genome and pangenome sizes.

Usage: #{$0} [options]"
   opts.separator ""
   opts.separator "Mandatory"
   opts.on("-o", "--ogs FILE",
      "Input file containing the precomputed OGs."){ |v| o[:ogs]=v }
   opts.separator ""
   opts.separator "Other Options"
   opts.on("-n", "--replicates INT",
      "Number of replicates to estimate. By default: #{o[:n]}."
      ){ |v| o[:n]=v.to_i }
   opts.on("-j", "--json FILE", "Output file in JSON format."){ |v| o[:json]=v }
   opts.on("-t", "--tab FILE","Output file in tabular format."){ |v| o[:tab]=v }
   opts.on("-s", "--summary FILE",
      "Output file in tabular format with summary statistics."
      ){ |v| o[:summ]=v }
   opts.on("-a", "--auto", "Run completely quiertly (no STDERR or STDOUT)") do
      o[:q] = true
      o[:a] = true
   end
   opts.on("-q", "--quiet", "Run quietly (no STDERR output)."){ o[:q] = true }
   opts.on("-h", "--help", "Display this screen.") do
      puts opts
      exit
   end
   opts.separator ""
end.parse!
abort "-o is mandatory" if o[:ogs].nil?

##### MAIN:
begin
   # Initialize the collection of OGs.
   collection = OGCollection.new
   
   # Read the pre-computed OGs
   $stderr.puts "Reading pre-computed OGs in '#{o[:ogs]}'." unless o[:q]
   f = File.open(o[:ogs], "r")
   h = f.gets.chomp.split /\t/
   while ln = f.gets
      collection << OG.new(h, ln.chomp.split(/\t/))
   end
   f.close
   $stderr.puts " Loaded OGs: #{collection.ogs.length}." unless o[:q]
   
   # Generate subsamples
   size = {core:[], pan:[]}
   (0 .. o[:n]-1).each do |i|
      genomes = (0 .. Gene.genomes.length-1).to_a.shuffle
      size[:core][i] = []
      size[:pan][i] = []
      while not genomes.empty?
	 size[:core][i].unshift(collection.ogs.map do |og|
	    (genomes - og.genomes).empty? ? 1 : 0
	 end.inject(0,:+))
         size[:pan][i].unshift(collection.ogs.map do |og|
	    ((genomes - og.genomes).length < genomes.length) ? 1 : 0
	 end.inject(0,:+))
	 genomes.pop
      end
   end

   # Show result
   $stderr.puts "Generating reports." unless o[:q]

   # Save results in JSON
   unless o[:json].nil?
      ohf = File.open(o[:json], "w")
      ohf.puts JSON.pretty_generate(size)
      ohf.close
   end

   # Save results in tab
   unless o[:tab].nil?
      ohf = File.open(o[:tab], "w")
      ohf.puts (%w{replicate metric}+(1 .. Gene.genomes.length).to_a).join("\t")
      (0 .. o[:n]-1).each do |i|
	 ohf.puts ([i+1,"core"] + size[:core][i]).join("\t")
	 ohf.puts ([i+1,"pan"] + size[:pan][i]).join("\t")
      end
      ohf.close
   end

   # Save summary results in tab
   unless o[:summ].nil?
      ohf = File.open(o[:summ], "w")
      ohf.puts %w{genomes core_avg core_sd core_q1 core_q2 core_q3
	 pan_avg pan_sd pan_q1 pan_q2 pan_q3}.join("\t")
      (0 .. Gene.genomes.length-1).each do |i|
	 res = [i+1]
	 [:core, :pan].each do |met|
	    a = size[met].map{ |r| r[i] }.sort
	    avg = a.inject(0,:+).to_f / a.size
	    sd = Math.sqrt(a.map{ |v| v**2 }.inject(0,:+)/a.size - avg**2)
	    q1 = a[ a.size*1/4 ]
	    q2 = a[ a.size*2/4 ]
	    q3 = a[ a.size*3/4 ]
	    res += [avg,sd,q1,q2,q3]
	 end
	 ohf.puts res.join("\t")
      end
      ohf.close
   end

   $stderr.puts "Done.\n" unless o[:q] 
rescue => err
   $stderr.puts "Exception: #{err}\n\n"
   err.backtrace.each { |l| $stderr.puts l + "\n" }
   err
end


