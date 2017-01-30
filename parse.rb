#!/usr/bin/env ruby
# vim: fdm=syntax

require 'yaml'
require 'pathname'
require 'bibtex'
require 'dr/ruby_ext/core_ext'

#parse sentences of the form "ploum LINK(plam,plim)" and replace LINK(plam,plim) by the result of a function
module Parse
	module_function
	#return the list of arguments to kw
	def keyword(msg,kw,**kwds,&block)
		h={kw => block}
		return keywords(msg,h,**kwds)
	end

	def keywords(msg,hash,**kwds)
		sep=kwds[:sep]||","
		#TODO making it not recursive is harder
		keywords=hash.keys
		keywords_r="(?:"+keywords.map {|k| "(?:"+k+")"}.join("|")+")"
		reg = %r{(?<kw>#{keywords_r})(?<re>\((?:(?>[^()]+)|\g<re>)*\))}
		if m=reg.match(msg)
			arg=m[:re][1...m[:re].length-1]
			arg=keywords(arg,hash,**kwds)
			args=arg.split(sep)
			key=keywords.find {|k| /#{k}/ =~ m[:kw]}
			r=hash[key].call(*args).to_s
			msg=m.pre_match+r+keywords(m.post_match,hash,**kwds)
			msg=keywords(msg,hash,**kwds) if kwds[:recursive]
		end
		return msg
	end
# re = %r{
#   (?<re>
#     \(
#       (?:
#         (?> [^()]+ )
#         |
#         \g<re>
#       )*
#     \)
#   )
# }x
#(?<re> name regexp/match
#\g<re> reuse regexp
#\k<re> reuse match
#(?: grouping without capturing
#(?> atomic grouping
#x whitespace does not count
# -> match balanced groups of parentheses
end

class DateRange
	class <<self
		#in: 2014-01-02 -> 2014-01-03, 2014-01-05, 2014-02 -> :now
		#out: [[2014-01-02,2014-01-03],[2014-01-05],[2014-02,:now]]
		def parse(date)
			return date if date.kind_of?(self)
			r=[]
			dates = date.to_s.chomp.split(/,\s*/)
			dates.each do |d|
				r << d.split(/\s*->\s*/).map {|i| i == ":now" ? :now : i }
			end
			return DateRange.new(r)
		end

		#BUG: années bissextiles...
		Months_end={1 => 31, 2 => 28, 3 => 31, 4 => 30,
			5 => 31, 6 => 30, 7 => 31, 8 => 31,
			9 => 30, 10 => 31, 11 => 30, 12 => 31}
		def to_time(datetime, complete_date: :first, **kwds)
			return Time.now if datetime == :now
			begin
				fallback=Time.new(0)
				return Time.parse(datetime,fallback)
			rescue ArgumentError
				year,month,day,time=split_date(datetime)
				case complete_date
				when :first
					month="01" if month == nil
					day="01" if day == nil
					time="00:00:00" if day == nil
				when :last
					month="12" if month == nil
					day=Months_end[month.to_i].to_s if day == nil
					time="23:59:59" if day == nil
				end
				return Time.parse("#{year}-#{month}-#{day}T#{time}",fallback)
			end
		end

		#ex: split 2014-07-28T19:26:20+0200 into year,month,day,time
		def split_date(datetime)
			datetime=Time.now.iso8601 if datetime == :now
			date,time=datetime.split("T")
			year,month,day=date.split("-")
			return year,month,day,time
		end

		Months_names={en: {
			1 => 'January', 2 => 'February', 3 => 'March',
			4 => 'April', 5 => 'May', 6 => 'June',
			7 => 'July', 8 => 'August', 9 => 'September',
			10 => 'October', 11 => 'November', 12 => 'December'},
			fr: {
			1 => 'Janvier', 2 => 'Février', 3 => 'Mars',
			4 => 'Avril', 5 => 'Mai', 6 => 'Juin',
			7 => 'Juillet', 8 => 'Août', 9 => 'Septembre',
			10 => 'Octobre', 11 => 'Novembre', 12 => 'Décembre'}}

		def abbr_month(month, lang: :en, **kwds)
			return month if month.length <= 4
			return month[0..2]+(lang==:en ? '.' : '')
		end

		def output_date(datetime, output_date: :abbr, output_date_length: :month,
			**kwds)
			lang=kwds[:lang]||:en
			year,month,day,time=split_date(datetime)
			month=nil if output_date_length==:year
			day=nil if output_date_length==:month
			time=nil if output_date_length==:day
			return Biblio.localize({en: 'Present', fr: 'Présent'},**kwds) if datetime==:now
			case output_date
			when :num
				r=year
				if month.nil?
					return r
				else
					r+="-"+month
				end
				if day.nil?
					return r
				else
					r+="-"+day
				end
				if time.nil?
					return r
				else
					r+="T"+time
				end
			when :abbr,:string
				r=year
				if month.nil?
					return r
				else
					month_name=Months_names[lang][month.to_i]
					month_name=abbr_month(month_name) if output_date==:abbr
					r=month_name+" "+r
				end
				if day.nil?
					return r
				else
					r=day+" "+r
				end
				if time.nil?
					return r
				else
					r+=" "+time
				end
			end
		end
	end

	attr_accessor :d, :t
	def initialize(d)
		@d=d
		@t=d.map do |range|
			case range.length
			when 1
				[DateRange.to_time(range[0], complete_date: :first),
				DateRange.to_time(range[0], complete_date: :last)]
			when 2
				[DateRange.to_time(range[0], complete_date: :first),
				DateRange.to_time(range[1], complete_date: :last)]
			else
				range.map {|i| DateRange.to_time(i)}
			end
		end
	end

	#sort_date_by :first or :last
	def <=>(d2,sort_date_by: :last,**kwds)
		d1=@t; d2=d2.t
		sel=lambda do |d|
			case sort_date_by
			when :last
				return d.map {|i| i.last}
			when :first
				return d.map {|i| i.first}
			end
		end
		best=lambda do |d|
			case sort_date_by
			when :last
				return d.max
			when :first
				return d.min
			end
		end
		b1=best.call(sel.call(d1))
		b2=best.call(sel.call(d2))
		return b1 <=> b2
	end

	def to_s(join: ", ", range_join: " – ", **kwds)
		r=@d.map do |range|
			range.map do |d|
				DateRange.output_date(d,**kwds)
			end.join(range_join)
		end.join(join)
		if r==""
			return nil
		else
			return r
		end
	end

end

#TODO: refactorize this mess of Biblio.self to its own class
class Biblio
	extend Forwardable
	attr_accessor :content
	def_delegators :@content, :'[]', :'[]='
	BIBKEYS=%i(title author year month url)

	WEBSITE="http://www.normalesup.org/~robert/"
	WEBPRO=WEBSITE+"pro/"
	WEBPERSO=WEBSITE+"perso/"
	WEBPUBLIS=WEBPRO+"publications/"
	WEBTEACHING=WEBPRO+"teaching/"

	Categories=Hash.new do |h,k|
			h[k]={name: k, type: :activity}
		end.merge({
			academic: {name: {fr: 'Académique', en: 'Academic'}, type: :publi},
			articles: {name: {fr: 'Articles', en: 'Articles'}, type: :publi},
			reports: {name: {fr: 'Rapports', en: 'Reports'}, type: :publi},
			:'teaching-talks' => {name: {fr: 'Exposés Cours', en: 'Teaching Talks'}, type: :publi},
			:'invited-talks' => {name: {fr: 'Conférencier invité', en: 'Invited Speaker'}, type: :publi},
			:'vulgarisation-talks' => {name: {fr: 'Exposés de Vulgarisation', en: 'Vulgarization Talks'}, type: :publi},
			talks: {name: {fr: 'Exposés', en: 'Talks'}, type: :publi},
			rump: {name: {fr: 'Rump Sessions', en: 'Rump Sessions'}, type: :publi},
			softwares: {name: {fr: 'Logiciels', en: 'Softwares'}, type: :publi},
			patents: {name: {fr: 'Brevets', en: 'Patents'}, type: :publi},
			publis: {name: {fr: 'Publications', en: 'Publications'}, type: :publi},
			preprints: {name: {fr: 'Prépublications', en: 'Preprints'}, type: :publi},
			phd: {name: {fr: 'Thèse', en: 'PhD Thesis'}, type: :publi},
			teaching: {name: {fr: 'Enseignement', en: 'Teaching'}, type: :activity},
			responsibilities: {name: {fr: 'Responsabilités', en: 'Responsibilities'}, type: :activity},
			:'responsibilities-talks' => {name: {fr: "Transparents d'activités", en: 'Activities Slides'}, type: :activity},
			comitees: {name: {fr: 'Comités', en: 'Comitees'}, type: :activity},
			students: {name: {fr: 'Étudiants', en: 'Students'}, type: :activity},
			vulgarisation: {name: {fr: 'Vulgarisation', en: 'Vulgarization'}, type: :activity},
			prizes: {name: {fr: 'Prix', en: 'Prizes'}, type: :activity},
			conferences: {name: {fr: 'Conférences suivies', en: 'Conferences attended'}, type: :activity},
			stays: {name: {fr: "Séjours à l'étranger", en: 'Foreign stays'}, type: :activity},
			confstays: {name: {fr: "Séjours à l'étranger et participation à des conférences", en: 'Foreign stays and conferences attended'}, type: :activity},
			juries: {name: {fr: 'Jurys', en: 'Juries'}, type: :activity},
			experiences: {name: {fr: 'Expériences', en: 'Experiences'}, type: :activity},
		})
		#merge teaching and teaching-talks by date
		Categories[:'teaching-all']=Categories[:teaching]
		Categories[:'vulgarisation-all']=Categories[:vulgarisation]

	class << self
		attr_accessor :meta
		attr_accessor :raw
		def authors
			@meta[:authors]
		end
		def meta
			@meta
		end
		def meta_all
			@meta[:all]
		end

		def add(articles,meta=nil)
			add_meta(meta) if meta
			(@raw||={}).deep_merge!(articles)
			r={}
			articles.each do |k,g|
				type=Categories[k][:type]
				g.each do |ka,a|
					a[:group]=k; a[:type]=type; a[:key]||=ka
					add_meta_info(a)
					warn "Key already there: #{ka}" if r.keys.include?(ka)
					r[ka]=Biblio.new(a)
				end
			end
			return r
		end

		def add_meta(meta)
			@meta||={}
			@meta.deep_merge!(expand_meta(meta))
			@meta[:all]||={}
			meta.each do |k,v|
				common=@meta[:all].keys & v.keys
				warn "@meta[:all]: Keys already there: #{common}" if common.length>0
				@meta[:all].merge!(v)
			end
		end

		def add_meta_info(a)
			if a[:group]==:responsibilities and not a[:granttype].nil?
				a=a.dup
				name=grant_type(a[:granttype]) #name may be localised
				case name
				when String
					name=join(name,a[:title])
				when Hash
					name.each do |k,v|
						name[k]=join(v,a[:title])
					end
				end
				a[:name]||=name
				ka=a[:key]
				add_meta({grant: {ka => a}})
			end
		end

		def expand_meta(meta)
			meta.fetch(:authors,{}).each do |k,a|
				name=a[:name]
				names=name.split
				bibname="#{names[-1]}, #{names[0...-1].join(" ")}"
				a[:bib]||={}
				a[:bib][:name]||=bibname
			end
			meta
		end

		def load(*files)
			r={}
			files.each do |filename|
				File.open(filename) do |file|
					streams = YAML.load_documents(file)
					nr=add(*streams)
					inter=Set.new(nr.keys).intersection(Set.new(r.keys))
					warn "Keys already there: #{inter.to_a}" unless inter.empty?
					r.merge!(nr)
				end
			end
			r.values.flatten.map(&:expand_content)
			return r
		end

		def group_name(g,**kwds)
			Biblio.localize(Biblio::Categories[g][:name], **kwds)
		end

		def group_title(g,**kwds)
			return title(group_name(g,**kwds),g,**kwds)
		end

		#Output a title; symbol may be the symbol which defined the title
		def title(t,symbol=nil,**kwds)
			unless kwds[:titletype]
				#we can't use outtype here because we are usually not inside Biblio#out
				kwds[:titletype]=:bib if kwds[:out]==:bib
				kwds[:titletype]=:web if kwds[:out]==:web
				kwds[:titletype]=:tex if kwds[:out].to_s=~/^tex/
			end
			case kwds[:titletype]
			when :web
				return "# #{t}"
			when :tex
				return "\\section{#{t}}"
			when :bib
				return "% "+t
			when :symbol
				return "# #{symbol}: "+t
			when :none
				return ''
			else
				return t.to_s
			end
		end

		def pre_post_from_group(group,out)
			pre=""; post=""; wrap=nil
			case out
			when :web; pre="- "
			when :tex,:texbib
				pre="\\item "
				wrap=:enum
			when :texcvlist
				pre="\\cvlistitem{"
				post="}"
				out=:tex
			when :texcvitem
				#nothing, this is handled in Biblio.info
			when :texcv
				case Biblio::Categories[group][:type]
				when :publi
					case group
					when :articles,:publis,:preprints
						return pre_post_from_group(group,:texcvlist).merge({out: :texbib})
					else
						return pre_post_from_group(group,:texcvlist).merge({out: :tex})
					end
				when :activity
					return pre_post_from_group(group,:texcvitem)
				end
			end
			return {pre: pre,post: post, out: out, wrap: wrap}
		end

		#process group is made for cv, to handle specially some groups of biblio
		#In Biblio#out, kwds[:out] can be
		#- :bib (bibtex output, will use the values of the :bibtex entries,
		#      outtype is bib for content[:bibtex] (main precedence) and tex for the rest (to complete bibtex entries))
		#- :texbib (\fullcite{ploum}, will merge :bibtex entries to recover the key if needed, pre will be set to '\item')
		#- :web (will merge :text entries, pre is '-')
		#- :tex (will merge :text entries, pre is '\item')
		#- :texcvitem (like :tex but use \cvitem{date}{rest}, will merge :text entries, pre is '\item')
		#Also as usual we merge the value of :outtype (:tex or :web) and then :out entries in Biblio.expand (:outtype can coincide with :out but so far I don't need to distinguish these cases)
		#(except for :texbib where we don't expand)
		#process_group also allows the following options:
		#- :texcvlist (like :tex, but pre is \cvlistitem}
		#- :texcv (automatically choose
		#     -:texbib for :articles,:preprints,:publis, with :texcvlist pre
		#     -:tex for the rest of perso.yaml, with :texcvlist pre
		#     -:texcvitem for activities.yaml
		def process_group(group,biblio,**kwds)
			case group
			when Array
				Biblio.join(group.map {|g| process_group(g,biblio,**kwds)},join:"\n")
			else
				return process_list(biblio[group],group: group,**kwds)
			end
		end

		def process_list(list,group: :individual,**kwds)
			out=kwds[:out]
			if group == :individual
				r=""
				list.each do |article|
					art=Biblio.expand(article.dup,**kwds)
					r+=title(art[:title],**kwds)+"\n"
					r+=process(article,**kwds)
				end
				return r
			else
				kwds[:title]||=group_title(group,**kwds)
				prepost=pre_post_from_group(group,out)
				wrap=prepost.delete(:wrap)
				kwds=prepost.merge(kwds)
				kwds[:out]=prepost[:out] #out may have changed, for ex if out was texcv
				r=kwds[:title]+"\n"
				s=process(list,**kwds)
				case wrap
				when :enum
					s=wrap_enum(s)
				end
				return r+s
			end
		end

		def process(articles,group:nil,**kwds)
			r=""
			articles=[articles] if not Array === articles
			articles.each do |article|
				r+=article.out(**kwds) unless article.nil?
			end
			return r
		end

		#biblio is of the form {:DRphd=>#<Biblio:0x97c7eec @content=..
		def categorize(biblio)
			phd=[biblio[:DRphd]] if biblio.key?(:DRphd)

			biblio=biblio.values
			notpublic=biblio.select {|b| b[:keyword] =~ /notpublic/}
			biblio-=notpublic
			bibgroup=biblio.group_by {|i| i[:group]}
			articles=bibgroup[:articles]
			if articles
				preprints=articles.select {|a| a[:keyword] =~ /preprint/ }
				publis=articles-preprints
			end

			bibgroup[:'teaching-all']=[bibgroup[:teaching],bibgroup[:'teaching-talks']].flatten.compact.sort_by {|i| i[:date]}.reverse
			bibgroup[:'vulgarisation-all']=[bibgroup[:vulgarisation],bibgroup[:'vulgarisation-talks']].flatten.compact.sort_by {|i| i[:date]}.reverse
			bibgroup[:confstays]=[bibgroup[:conferences],bibgroup[:stays]].flatten.compact.sort_by {|i| i[:date]}.reverse

			bibgroup.merge!({notpublic: notpublic,
				publis: publis, preprints: preprints,
				phd: phd}).delete_if {|k,v| v==nil or v.empty?}
			return bibgroup
		end

		def std_bibgroups #for publication*.tex
			return %i(preprints publis reports phd invited-talks
				teaching-talks talks vulgarisation-talks rump
				softwares patents)
		end
		def bib_bibgroups #for biblio*_all*.bib
			return std_bibgroups + [:notpublic]
		end
		def pubbib_bibgroups #for biblio*.bib
			return std_bibgroups
		end
		def web_bibgroups #for publications/index*.page
			return %i(preprints publis reports invited-talks
				talks rump phd)
		end
		def webteach_bibgroups #for teaching/index*.page
			return %i(teaching-all students vulgarisation-all)
		end
		def webrespo_bibgroups #for responsibilitie*.paga
			return %i(responsibilities comitees responsibilities-talks experiences)
		end
		def cv_bibgroups #for cv*.tex
			return %i(publis preprints reports phd prizes softwares teaching-all students responsibilities comitees invited-talks talks vulgarisation-all responsibilities-talks patents confstays)
			#experiences is included before in the first part
		end

		def localize(msg,lang: :en,**kwds)
			case msg
			when Hash
				if msg.key?(lang)
					return msg[lang]
				else
					return nil
				end
			else
				return msg.to_s
			end
		end

		def expand_symbol(sym,links=meta_all,symbol: :auto,**kwds)
			return sym if symbol==:never
			warn "#{sym} not found in #{links}" unless links[sym]
			content=expand(links[sym],**kwds)
			if (symbol == :url) or (symbol == :auto and Hash===content and content.key?(:url))
				return make_link(content,**kwds)
			elsif symbol == :name and Hash===content and content.key?(:name)
				return content[:name]
			else
				return content
			end
		end

		def get_symbol(sym)
			case sym
			when Symbol
				return sym, true
			when String
				return sym[1...sym.length].to_sym, true if sym[0] == ':'
			end
			return sym, false
		end
		def try_expand_symbol(sym,**kwds)
			key,r=get_symbol(sym)
			return expand_symbol(key,**kwds), r if r
			return sym, r
		end

		#if args is of size 1 and an array we join the elements of this array
		def join(*args, pre: "", post: "", pre_item: "", post_item: "", join: :auto, **kwds)
			args=args.first if args.length==1 and Array===args.first
			args=args.map {|i| try_expand_symbol(i,**kwds).first}
			list=args.compact.map {|i| pre_item+i+post_item}.delete_if {|i| i.empty?}
			r=list.shift
			list.each do |s|
				if join==:auto
					if r[r.length-1]=="\n" or s[1]=="\n"
						r+=s
					else
						r+=" "+s
					end
				else
					r+=join+s
				end
			end
			if r.nil? or r.empty?
				return nil
			else
				return pre+r+post
			end
		end

		def expand(msg, **kwds)
			lang=kwds[:lang]
			recursive=kwds[:recursive]
			case msg
			when Hash
				outtype=kwds[:outtype]
				out=kwds[:out]
				clean_nil=kwds.fetch(:clean_nil,true)
				if msg.key?(outtype)
					msg=msg.merge(msg[outtype])
					msg.delete(outtype)
				end
				if msg.key?(out)
					msg=msg.merge(msg[out])
					msg.delete(out)
				end
				if msg.key?(:content)
					return expand(msg[:content],**kwds)
				elsif msg.key?(lang)
					return expand(msg[lang],**kwds)
				else
					if recursive
						msg_exp={}
						#if recursive is :first, then we only expand the first hash value
						kwds[:recursive]=false if recursive==:first
						msg.each do |k,v|
							msg_exp[k]=expand(v,**kwds)
						end
						#expand may have introduced nil values
						msg_exp.delete_if {|k,v| v==nil} if clean_nil
						return msg_exp
					else
						return msg
					end
				end
			when Symbol
				kwds[:symbol]||=:never
				#if recursive is :first, then we only expand the first hash value
				kwds[:recursive]=false if recursive==:first
				return expand_symbol(msg,**kwds)
			when Array
				if recursive
					msg=msg.map {|i| expand(i,**kwds)}
					join=kwds[:join]
					if join
						return Biblio.join(msg, **kwds)
					else
						return msg
					end
				else
					return msg
				end
			when String
				msg,sucess=try_expand_symbol(msg,**kwds)
				if sucess
					return msg
				else
					hlang=lambda do |*args|
						h={}
						args.each do |arg|
							k,w=arg.split(':')
							h[k.to_sym]=w
						end
						warn "No localisation for #{lang} in #{args}" unless h.key?(lang)
						return h[lang]||""
					end

					hlink=lambda do |*args|
						case args.length
						when 1
							name=args.first
							exp,res=try_expand_symbol(name,link: :url,**kwds)
							if res
								return exp
							else
								make_link(name,**kwds)
							end
						else
							#hack: when there are several arguments assume the first ones
							#are normal commas
							name,url=args[0...-1].join(','),args[-1]
							#warn "LINK called with too many args: #{args}, merging them" if args.length >2
						end
						make_link(name,url,**kwds)
					end

					hexp=lambda do |*args|
						case args.length
						when 1
							name=args.first
							exp,res=try_expand_symbol(name,**kwds)
							if res
								return exp
							else
								return expand_symbol(name.to_sym,**kwds)
							end
						else
							warn "EXPAND called with too many args: #{args}"
						end
					end

					return Parse.keywords(msg,{'LANG'=>hlang,'(?:EXP|EXPAND)'=>hexp,'LINK'=>hlink},recursive: true)
				end
			when nil
				return nil
			else
				return msg
				#expand(msg.to_s,**kwds)
			end
		end

		#make_link name url
		#if url is not set, use name=url
		#if given a hash, extract name and url and makes link
		# (if only url is given use name=url)
		# (if only name is given output name and don't give a link)
		def make_link(*args,relative: true,cur_url: WEBPRO, **kwds)
			msg=args.first
			if Hash===msg
				begin
					if msg.key?(:url)
						if msg.key?(:name)
							return make_link(msg[:name],msg[:url],**kwds)
						else
							return make_link(msg[:url],**kwds)
						end
					else
						return msg[:name]
					end
				rescue Exception => e
					warn "#{msg.to_s} does not correspond to an url: #{e.to_s}"
				end
			else
				outtype=kwds[:outtype]
				name=localize(args.shift,**kwds)
				url=args.shift || name
				case outtype
				when :tex
					url=Biblio.tex_quote(url)
					if name == url
						return "\\url{#{url}}"
					else
						return "\\href{#{url}}{#{name}}"
					end
				when :texsee
					if name == url
						return "\\voirseelink{#{args[0]}}"
					else
						return "\\voirseelink[#{args[0]}]{#{args[1]}}"
					end
				when :web
					if relative and url =~ /^#{cur_url}/ and not url =~ /^#{cur_url}$/
						url=url.sub(/^#{cur_url}/,'')
						url=relative_link(url,kwds[:cur_folder])
					end
					if name == url
						return "<#{name}>"
					else
						return "[#{name}](#{url})"
					end
				end
			end
		end

		#take a relative url, and make it relative with respect to cur_folder
		#WARNING: assume that cur_folder is only of level 1 ie ploum/ and not
		#ploum/plam:
		def relative_link(relurl,cur_folder=nil)
			return relurl if ! cur_folder or cur_folder.empty?
			cur_folder+='/' unless cur_folder[cur_folder.length-1]='/'
			if relurl=~/^#{cur_folder}/
				return relurl.sub(/^#{cur_folder}/,'')
			else
				return "../"+relurl
			end
		end

		def complete_link(k,l,**kwds)
			outtype=kwds[:outtype]
			lang=kwds[:lang]
			name=k.to_s
			#url
			case k
			when :Slides
				url=l
			when :TEL
				url="http://tel.archives-ouvertes.fr/#{l}"
			when :HAL
				url="http://hal.archives-ouvertes.fr/#{l}"
			when :eprint
				url="http://eprint.iacr.org/#{l}"
			when :doi
				url="http://dx.doi.org/#{l}"
			when :arxiv
				arxivname,_arxivclass=l.split
				url="http://arxiv.org/abs/#{arxivname}"
			end
			#name
			name="Transparents" if k == :Slides and lang == :fr
			if k==:doi
				case lang
				when :en; name="Published version"
				when :fr; name="Version publiée"
				end
				#some doi are annoying
				l=Biblio.tex_quote(l)
			end
			#do link
			case outtype
			when :tex
				if k==:Slides
					shortl=l.split('/').last
					return name+": "+make_link(shortl,url,**kwds)
				else
					return name+": "+make_link(l,url,**kwds)
				end
			when :web
				return make_link(name,url,**kwds)
			end
		end

		#name (length, what, date, where, info)
		def handle_links(links,**kwds)
			return nil unless links
			return Biblio.join(links.each.map do |k,l|
				if k==:Slides and Hash===l
					l=get_file_and_url(l,"talks",**kwds)
					l=expand_conf(l)
					date=l[:date].nil? ? nil : DateRange.parse(l[:date]).to_s(output_date: :string, **kwds)
					name=complete_link(k,l[:url],**kwds)
					info=Biblio.join([l[:length],Biblio.expand(l[:what],**kwds),date,l[:where],l[:info]],join:", ",**kwds)
					name+(info.empty? ? "" : " ("+info+")")
				else
					complete_link(k,l.to_s,**kwds)
				end
			end, join:', ',**kwds)
		end

		def output_prepubli(prepubli,lang: :en,**kwds)
			return prepubli unless prepubli
			case lang
			when :en
				return "Accepted for publication at "+prepubli
			when :fr
				return "Accepté pour publication dans "+prepubli
			end
		end

		def get_bib_key(key,lang: :en,**kwds)
			if lang == :en
				return key.to_s
			else
				return key.to_s+lang.to_s.upcase
			end
		end

		#if args is of size 1 and an array we use it
		def sublist(*args,**kwds)
			args=args.first if args.length==1 and Array===args.first
			case kwds[:outtype]
			when :web
				return join(args,join:"\n",pre_item:"  - ")
			when :tex
				preitem="\\item "
				#preitem="\\cvitem " if kwds[:cv]
				return join(args,join:"\n",pre_item: preitem,
					pre:"\\begin{itemize}\n", post:"\n\\end{itemize}")
			end
		end

		def tex_quote(s)
			s=s.gsub('\\','\\textbackslash ')
			"&%$#_{}".each_char do |c|
				s=s.gsub(c,'\\'+c)
			end
			s=s.gsub('~','\\textasciitilde{}')
			s=s.gsub('^','\\textasciicircum{}')
		end

		def wrap(content,pre:nil,post:nil)
			return content if content.nil? or content.empty?
			return pre.to_s+content.to_s+post.to_s
		end
		def wrap_item(content)
			wrap(content,pre:"\\begin{itemize}\n",post:"\\end{itemize}\n")
		end
		def wrap_enum(content)
			wrap(content,pre:"\\begin{enumerate}\n",post:"\\end{enumerate}\n")
		end
		def wrap_paren(content)
			wrap(content,pre:"(",post:")")
		end

		def get_file_and_url(hash,group=nil,**kwds)
			group||=hash[:group]
			if group
				firstdir="publications/"
				firstdir="teaching/" if group.to_s =~ /^(teaching|vulgarisation)/
				firstdir="responsibilities/" if group.to_s =~ /^(responsibilities|experiences)/
				dirname=
					if group.to_s =~ /talks$/
						"slides/"
					else
						group.to_s+"/"
					end
				hash[:webdir]||=firstdir+dirname
				hash[:texdir]||=dirname
			end
			hash[:webfile] ||= hash[:webdir]+hash[:webname]+".pdf" if hash.key?(:webdir) and hash.key?(:webname)
			hash[:texfile] ||= hash[:texdir]+hash[:texname]+"_web.pdf" if hash.key?(:texdir) and hash.key?(:texname)
			hash[:texabsfile] ||= "#{ENV['HOME']}/latex"+hash[:texfile] if hash.key?(:texfile)
			hash[:rel_url]||=hash[:webfile] if hash.key?(:webfile)
			hash[:url]||=Biblio::WEBPRO+hash[:rel_url] if hash.key?(:rel_url)
			return hash
		end

		def grant_type(type)
			case type
			when :anr
				return "ANR"
			when :'anr-industrial'
				return {en: "Industrial ANR", fr: "ANR Industrielle"}
			when :erc
				return "ERC"
			else
				return type.to_s
			end
		end

		#expand :conf entry
		def expand_conf(entry)
			sym,r=Biblio.get_symbol(entry[:conf])
			if r #automatically retrieve information 
				conf=Biblio.raw[:conferences][sym].dup
				return conf.merge(entry) if conf
			end
			entry
		end
	end

	#Used to expand symbols
	#perso.yaml define three metainformations key: :authors, :links, :expand;
	#they are all merged in :all
	Biblio.add_meta({ authors: {
			me: {name: "Damien Robert", url: WEBPRO, bib: {name: "Robert, Damien"}}
		},
		links: {
			website: WEBSITE, webpro: WEBPRO, webperso: WEBPERSO,
			webpublis: WEBPUBLIS, webteaching: WEBTEACHING,
		},
		expand: {
			inpreparation: {en: "In preparation.", fr: "En préparation."},
		},
	})


	def initialize(hash, key: nil)
		@content=hash
		@content[:key]||=key if key
		#this is not necessary since the hash is passed by reference but I find
		#it clearer
		@content=Biblio.get_file_and_url(@content)
		handle_date
		complete_content
	end

	def handle_date
		@content[:year]=@content[:year].to_i if @content.key?(:year)
		@content[:month]=@content[:month].to_i if @content.key?(:month)
		if @content.key?(:date)
			@content[:date]=DateRange.parse(@content[:date])
			datetime=@content[:date].d.first.first
			year,month=DateRange.split_date(datetime)
			@content[:year]||=year.to_i
			@content[:month]||=month.to_i
		else
			if @content.key?(:year)
				r=@content[:year].to_s
				if @content.key?(:month)
					month=@content[:month].to_s
					month="0"+month if month.length == 1
					r+="-"+month.to_s
				end
				@content[:date]=DateRange.parse(r)
			end
		end
	end

	#used at init
	def complete_content
		@content[:info]=Biblio.join(@content[:info], "EXP(:inpreparation)") if @content[:keyword] =~ /inpreparation/
	end

	#called by Biblio.load, after we have loaded the full biblio files
	def expand_content
		@content=Biblio.expand_conf(@content)
	end

	def to_s(**kwds)
		exp=Biblio.expand(@content.dup,recursive: true,**kwds)
		return Biblio.join(exp[:title],Biblio.wrap_paren(exp[:group]))
	end

	def out(pre:nil,post:nil,**kwds)
		#note: pre ou post can be defined in this function,
		#but there is also a specific @content[:pre] and @content[:post]
		#which is handled in info(...) too
		out=kwds[:out] || :string
		case out
		when :string; r=to_s(**kwds)
		when :bib; r=to_bib(**kwds)
		when :web; r=to_web(**kwds)
		when :tex,:texcvitem; r=to_tex(**kwds)
		when :texbib; r=to_texbib(**kwds)
		end
		return pre.to_s+r.to_s+post.to_s+"\n"
	end

	def to_texbib(**kwds)
		kwds[:outtype]=:tex
		tex=@content.dup
		#recover key if its in :bibtex
		tex.merge!(@content[:bibtex]) if @content.key?(:bibtex)
		#tex=Biblio.expand(tex,**kwds)
		key=Biblio.get_bib_key(tex[:key],**kwds)
		return "\\fullcite{#{key}}"
	end

	#howpublished=howpublished. prepubli. what, where.
	#addendum=addendum. links. info
	#(note biblatex output the fields as authors. title. howpublished. note.
	#date. url. addendum.)
	def to_bib(**kwds)
		kwds[:outtype]=:tex
		exp=@content.dup
		#for biblio, we don't want links in the author field so get the value before the expansion
		authors=(exp.key?(:bibtex) ? exp[:bibtex][:author] : nil) || exp[:author]
		bib=Biblio.expand(exp[:bibtex],recursive: true,**kwds) || Hash.new()
		exp=Biblio.expand(exp,recursive: true,**kwds)
		BIBKEYS.each { |k| bib[k]||=exp[k] if exp.key?(k) }

		bib[:author]=Biblio.join(authors, symbol: :name, join: " and ",**kwds) if authors.class == Array
		bib[:author]||=Biblio.meta_all[:me][:bib][:name]
		bib[:keywords]||="perso,"+exp[:group].to_s if exp.key?(:group)

		exp[:where]=nil if bib[:school] #horrible hack for phdthesis, the :where info is already present in :school
		bib[:note]=Biblio.join(bib[:note],bib[:howpublished],Biblio.output_prepubli(exp[:prepubli],**kwds),Biblio.join(%i(what where).map {|i| exp[i]},join:", ",**kwds),post_item:".",**kwds)

		#links
		links=exp[:links]
		doi=links.delete(:doi) if links
		bib[:doi]||=doi if doi
		arxiv=links.delete(:arxiv) if links
		if arxiv
			bib[:eprinttype]="arxiv"
			arxivname,arxivclass=arxiv.split
			bib[:eprint]=arxivname
			bib[:eprintclass]=arxivclass
		end
		links=Biblio.join(Biblio.handle_links(links,**kwds),post:'.')
		#maybe I should add extralinks here, but I don't really want them in
		#the biblio
		bib[:addendum]=Biblio.join(links,exp[:info],bib[:addendum],**kwds)

		bib.delete_if {|k,v| v==nil}
		b=BibTeX::Entry.new(bib)
		b.key=Biblio.get_bib_key(exp[:key],**kwds).to_sym
		b.type=(exp[:bibtype]||:unpublished).to_sym
		return b
	end

	def to_web(**kwds)
		kwds[:outtype]=:web
		return info(**kwds)
	end

	def to_tex(**kwds)
		kwds[:outtype]=:tex
		return info(**kwds)
	end

	#title=title post_title (level, length)
	#title=role grant title (acro) #in :responsibilities
	#authors=authors post_author
	#titleauthors=authors, title, with.
	#whatdate=publi, what date where.
	#links=(links, extra_links.)
	#-> pre titleauthors whatdate links info
	#   extrainfo
	#   post
	def info(**kwds)
		info=@content.dup
		info.merge!(info[:text]) if info.key?(:text)
		info=Biblio.expand(info,recursive: true,clean_nil: false,**kwds)

		if info.key?(:url)
			title=Biblio.make_link(info[:title],info[:url],**kwds)
		else
			title=info[:title].to_s
		end
		title=Biblio.wrap(title,pre:"*",post:"*") if kwds[:outtype]==:web
		extratitle=Biblio.join(info[:level],info[:length],join:', ',**kwds)
		title=Biblio.join(title,info[:post_title], Biblio.wrap_paren(extratitle), **kwds)
		if info[:group]==:responsibilities
			grant=Biblio.localize(Biblio.grant_type(info[:granttype]),**kwds)
			case info[:role]
			when :member
				role=Biblio.localize({en: "Member of the ", fr: "Membre de l'"},**kwds)
			end
			title=Biblio.join(role,grant,title,Biblio.wrap_paren(info[:acro]))
		end

		authors=Biblio.join(info[:author], join: ", ",**kwds)
		authors=Biblio.join(authors,info[:post_author],**kwds)
		withintro=Biblio.localize({en: "with ",fr: "avec "},**kwds)
		withintro=Biblio.localize({en: "cosupervising with ", fr: "cosupervision avec "}) if info[:group]==:students
		with=Biblio.wrap(Biblio.join(info[:with],join: ", ",**kwds), pre:withintro)
		titleauthors=Biblio.join(authors,title,with,join:", ",post:'.',**kwds)

		publi=info[:publi] || Biblio.output_prepubli(info[:prepubli],**kwds)
		what=info[:what]
		#we may need to parse the date again in case it was merged
		date=case info[:date]
			when nil; nil
			when String; DateRange.parse(info[:date]).to_s(output_date: :string, **kwds)
			when DateRange; info[:date].to_s(output_date: :string, **kwds)
			end
		where=info[:where]

		list=[publi,what,date,where]
		list=list.delete_if {|i| i==date} if kwds[:out]==:texcvitem
		whatdate=Biblio.join(list,join:', ',post:'.',**kwds)

		links=Biblio.join(Biblio.handle_links(info[:links],**kwds),info[:extra_links],join:', ',pre:'(',post:'.)')
		inf=info[:info]
		if info[:group]==:comitees
			roles=Biblio.join([*info[:role]].map do |i|
				case i
				when :scientific
					role=Biblio.localize({en: "Scientific Comitee", fr: "Comité scientifique"},**kwds)
				when :organisation
					role=Biblio.localize({en: "Organisation Comitee", fr: "Comité d'organisation"},**kwds)
				end
			end,join: ', ',post:'.',**kwds)
			inf=Biblio.join(roles,inf,**kwds)
		end

    extrainfo=Biblio.wrap(Biblio.sublist(info[:extrainfos],**kwds),pre:"\n")
		r=Biblio.join(info[:pre],titleauthors,whatdate,links,inf,extrainfo,info[:post],**kwds)
		case kwds[:out]
		when :texcvitem
			return "\\cvitem{#{date}}{#{r}}"
		else
			return r
		end
	end
end

if __FILE__ == $0
	require "optparse"
	opts={out: :string, lang: :en}
	optparse = OptionParser.new do |opt|
		opt.banner = "Parse bibliography yaml files and output bibtex or markdown/kramdown"
		opt.on("--out=OUT", [:bib,:web,:string,:links,:tex,:texbib,:texcv,:texcvitem,:texcvlist], "Output mode", "Default: string") do |v| opts[:out]=v end
		opt.on("--lang=LANG", [:en,:fr], "Lang", "Default: en") do |v| opts[:lang]=v end
	end
	optparse.parse!

	biblio=Biblio.categorize(Biblio.load(*ARGV))
	groups=biblio.keys #Biblio.std_bibgroups
	if opts[:out] == :links
		puts Biblio.join(Biblio.meta_all.each.map do |k,v|
			"["+v[:name].to_s+"]: "+v[:url].to_s if Hash === v and v.key?(:name)
		end, join:"\n")
		exit
	end
	kwds=opts
	puts Biblio.process_group(groups,biblio, titletype: :symbol,**kwds).to_s+"\n"
	#puts Biblio.process_group(groups,biblio, cur_folder: 'publications/', **kwds)+"\n"
	#puts Biblio.process_list(biblio[:softwares], **kwds)+"\n"
end
