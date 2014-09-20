#!/usr/bin/env ruby
# vim: fdm=syntax

require './parse'

def generate(type,**kwds)
	r=""
	groups=case type
		when :public; Biblio.pubbib_bibgroups
		when :perso; Biblio.bib_bibgroups
		end
	groups.each do |group|
		r+=Biblio.process_group(group,@biblio, **kwds)
	end
	return r
end

def process(type,file, **kwds)
	f=Pathname.new(File.dirname(caller[0]))+"#{file.to_s}.bib"
	puts "- Writing to #{f.to_s}"
	data=generate(type,**kwds)
	f.write(data)
end

def run
	@biblio=Biblio.categorize(Biblio.load("./perso.yaml"))
	kwds={}
	process(:perso,"biblio_damien_robert_all_en", out: :bib, lang: :en, **kwds)
	process(:perso,"biblio_damien_robert_all_fr", out: :bib, lang: :fr, **kwds)
	process(:public,"biblio_damien_robert_en", out: :bib, lang: :en, **kwds)
	process(:public,"biblio_damien_robert_fr", out: :bib, lang: :fr, **kwds)
end

run
