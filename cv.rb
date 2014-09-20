#!/usr/bin/env ruby
# vim: fdm=syntax

require './parse'
require 'dr/shell'
#Note sur \cventry:
# usage : \cventry{years}{degree/job title}{institution/employer}{localization}{optional: grade/...}{optional: comment/job description}
# Output is "Year" (marge) "Title" (bold), "Institution" (italic),
# "Localization", "Optional 1" \n "Optional 2" (small font)
# ex: \cventry{year--year}{Degree}{Institution}{City}{\textit{Grade}}{Description}

def font
	return <<EOS
\\usepackage[sel/garamondpremiertext]{myluafonts}
\\addfontfeatures{Numbers=OldStyle,Ligatures=Rare}%not working on GaramondPremier? :-(
EOS
end

def header(type,title, **kwds)
	lang=kwds[:lang]
	bibfile=(kwds[:bibfile] or lang == :en ? "perso" : "perso_#{lang}")
	r=""
	case lang
	when :en
		hlang="mainlang=english"
		extrainfo="French, Born in 1984"
		cvcolor="green"
	when :fr
		hlang="mainlang=french,otherlang=english"
		extrainfo="Né en 1984, Français"
		cvcolor="blue"
	end
	case type
	when :article; hclass="scrartcl"
	when :cv; hclass="moderncv"
	end
	bibfonttitle=<<EOS
\\bibliography{#{bibfile}}
#{font}
\\newcommand\\mytitle{#{title}}
\\title{\\mytitle}
EOS
	r+="\\RequirePackage[#{hlang},class=#{hclass}]{myclassoptions}\n"
	case type
	when :article
		r+=<<'EOS' +
\documentclass[\mydocumentoptions]{\mydocumentclass}
\usepackage[biblatex]{mypackages}
EOS
bibfonttitle+<<'EOS'
\newcommand\myauthor{Damien Robert}
\newcommand\mydate{\today}
\let\mypdftitle\mytitle
\let\mypdfauthor\myauthor
\newcommand\mypdfkeywords{publications}
\newcommand\mypdfsubject{list of publications}
\hypersetup{pdftitle={\mypdftitle},
            pdfauthor={\mypdfauthor},
            pdfkeywords={\mypdfkeywords},
            pdfsubject={\mypdfsubject}}
\author{\myauthor}
\date{\mydate}

\begin{document}
\label{ploum@ploum}
\PackageWarning{}{############## Beginning of document #####################}
\maketitle
EOS
	when :cv
		r+=<<'EOS' +
\documentclass[\mydocumentoptions,9pt%
]{\mydocumentclass}

\newcommand\linkcolor{gray}
\usepackage[biblatex]{mypackages}
\usepackage[scale=0.8]{geometry}

\moderncvstyle{myclassic}
EOS
"\\moderncvcolor{#{cvcolor}}\n"+bibfonttitle+<<'EOS'+
\firstname{Damien}
\familyname{R\scalebox{0.8}{\textls{OBERT}}}
%\familyname{\textsc{ROBERT}}
\subtitle{Inria Bordeaux Sud-Ouest}
\address{Libourne, France}
\phone[mobile]{+33 (0)6 66 56 25 49}
\phone[fixed]{+33 (0)5 40 00 21 56}
\email{damien.robert@inria.fr}
\homepage{\mysiteroot}
EOS
"\\extrainfo{#{extrainfo}}\n"+<<'EOS'
\photo[64pt][0pt]{robertdamien}
\social[github]{DamienRobert}

\newcommand{\mysiteroot}{www.normalesup.org/\string~robert/}
\newcommand{\mysitepro}{www.normalesup.org/\string~robert/pro/}

\begin{document}
\hypertarget{CV}{}
\bookmark[level=0,dest=CV]{CV}
\makecvtitle
EOS
	end
	return r
end

def main(type, **kwds)
	lang=kwds[:lang]
	groups=Biblio.std_bibgroups
	r=""
	case type
	when :all
		@biblio.each do |k,w|
			r+="\\section{#{k}: #{Biblio.group_name(k, lang: :en,out: :string,**kwds)} / #{Biblio.group_name(k, lang: :fr,out: :string,**kwds)}}\n"
			s=""
			w.each do |a|
				s+="\\item #{Biblio::tex_quote(a[:key].to_s)}:\\\\\n"
				if Biblio::Categories[a[:group]][:type]==:publi
					s+=a.out(out: :texbib, lang: :en, pre: "\\cite{#{Biblio.get_bib_key(a[:key],lang: :en,**kwds)}} ", post:'\\\\')
					s+=a.out(out: :texbib, lang: :fr, pre: "\\cite{#{Biblio.get_bib_key(a[:key],lang: :fr,**kwds)}} ",post:'\\\\')
				end
				s+=a.out(lang: :en, pre:'', post:'\\\\', **kwds)
				s+=a.out(lang: :fr, pre:'', post:'\\\\', **kwds)
			end
			#Hack: when extrainfo is set, we finish by '\end{itemize}\\' and
			#latex errors out: There's no line here to end.
			s.gsub!('\\end{itemize}\\\\','\\end{itemize}')
			r+=Biblio.wrap_enum(s)
		end
		r+=<<'EOS'
\nocite{*}
\printbibliography
EOS
	when :publi
		r+=Biblio.process_group(groups,@biblio, **kwds)
	when :cv
		groups=Biblio.cv_bibgroups
		#Partie CV
		case lang
		when :en
			midtitle="Scientific activities"
			r+=<<'EOS'+
\section{Research}
List of publications: \seebiglink{\mysitepro publications/}, see also \textit{\grayhyperlink{appendix}{the appendix}}.

\section{Work}
\cventry{March~2012--Present}{Researcher}{Inria Bordeaux Sud-Ouest, Bordeaux}{Inria Team LFANT}{}{Elliptic curves, abelian varieties and algorithmic number theory applied to cryptography}
\cventry{August~2011--February~2012}{Researcher Engineer}{Microsoft Research, Redmond}{Team manager: Kristin Lauter}{}{Developing the Microsoft cryptographic library.}
\cventry{October~2010--August~2011}{Postdoc}{Inria Bordeaux Sud-Ouest, Bordeaux}{Team manager: Andreas Enge}{}{Genus~$2$ curves and complex multiplication.}
\cventry{July~2010--September~2010}{Microsoft Research Summer Internship}{Redmond, USA}{Mentor: Kristin Lauter}
{}{Speeding up the CRT method in genus~$2$ for generating class polynomials}

\section{Education}
\cventry{January~2007--June~2010}{PhD Thesis}{University Henri Poincaré and Loria, Nancy}{Advisor: Guillaume Hanrot}
{Teaching Fellow (Moniteur) in Computer Science}
{Theta functions and applications in cryptography. Defended July
23 2010.}
\cventry{September--December~2006}{Master of Science in Computer Science}{Paris}{Master Parisien de Recherche Informatique}{(Inscription Pédagogique)}{Courses in cryptography and algebraic number
theory}
\cventry{2004--2006}{Master of Science in Mathematics}{Paris VI, Paris VII,
Paris XI, École Polytechnique}{Algebra and Geometry}{With Honors \footnotesize(Courses: 19.88/20, Master Thesis: 18/20, Total: 18.94/20)}{(Pedagogic inscription in 2004--2005.)
 Master Thesis on ``Classification of complex reflexion groups'',
 Advisor: Michel Broué (Institut Henri Poincaré).}
\cventry{2004--2005}{Agrégation in Mathematics}{}{Nationwide competitive
examination for recruiting teachers for undergraduate students}{Rank~9}{}
\cventry{2003--2007}{École Normale Supérieure}{Paris}{Computer Science}{Admitted after the French ``Grandes Écoles'' competitive examination, Rank~1}{}
\subcventry{2003--2006}{Magistère in Mathematics (MMFAI)}{}{With Honors}{}{}
\subcventry{2003--2004}{Bachelor of Science in Mathematics (L3--M1)}{}{With Honors \footnotesize(L3: 19/20, M1 Courses: 18.67/20, M1 Thesis: 14/20, M1 Total: 17/20)}{}{
Minor in Computer Science.
Bachelor Thesis on « Clifford modules and $K$-theory », with Mehdi
Tibouchi, advisor François Pierrot.}
EOS
			Biblio.process_group(:experiences,@biblio, **kwds)+<<'EOS'
\section{Langages}
\cvlanguage{French}{Native Speaker}{}
\cvlanguage{English}{Fluent}{I have lived one year in Knoxville, Tennessee}
\cvlanguage{German}{Basic}{}

\section{Technical Skills}
\cvcomputer{Programing}{\small C, \textsc{Java}, Ocaml, Perl, PHP, Ruby, Shell}{OS}{Linux (Archlinux)}
\cvcomputer{Scientific}{Magma, Matlab, Pari, Sage}{VCS}{Git, Mercurial, Subversion}
\cvcomputer{Web}{(X)HTML, CSS, Javascript}{Typography}{\LuaLaTeX}

\section{Hobbies}
\cvitem{Sport}{\small Juggling, Rock Climbing, Tennis.}
\cvitem{Safety}{\small French First Aid Certificate}
\cvitem{Other}{\small Driving license.}
EOS
		when :fr
			midtitle="Activités scientifiques"
			r+=<<'EOS'+
\section{Recherche}
Liste des publications: \seebiglink{\mysitepro publications/}, voir aussi \textit{\grayhyperlink{appendix}{l'appendice}}.

\section{Expérience professionnelle}
\cventry{Mars~2012--Actuel}{Chargé de Recherche}{Inria Bordeaux Sud-Ouest, Bordeaux}{Équipe projet LFANT}{}{Courbes elliptiques, variétés abéliennes et théorie algorithmique des nombres appliquées à la cryptographie}
\cventry{Août~2011--Février~2012}{Ingénieur Chercheur}{Microsoft Research, Redmond}{Chef d'équipe: Kristin Lauter}{}{Développement de la librairie cryptographique de Microsoft}
\cventry{Octobre~2010--Août~2011}{Postdoctorant}{Inria Bordeaux Sud-Ouest, Bordeaux}{Chef d'équipe: Andreas Enge}{}{Genus~$2$ curves and complex multiplication. Responsable de l'organisation des séminaires de l'équipe LFANT à l'Institut Mathématiques de Bordeaux.}
\cventry{Juillet~2010--Septembre~2010}{Stage à Microsoft Research}{Redmond, États-Unis}{Mentor: Kristin Lauter}
{}{Génération de polynômes de classe en genre~$2$ par la méthode des restes
Chinois}

\section{Parcours}
\cventry{Janvier~2007--Juin~2010}{Thèse}{Université Henri Poincaré et Loria, Nancy}{Directeur: Guillaume Hanrot}
{Monitorat en informatique}
{Fonctions thêta et applications à la cryptographie. Soutenue le
21 Juillet 2010.}
\cventry{Septembre--Décembre~2006}{MPRI}{Paris}{Master Parisien de
Recherche Informatique}{(Inscription pédagogique)}{Remise à niveau en informatique (cryptographie),
suivi du cours de M2 de théorie des nombres à Orsay.}
\cventry{2004--2006}{Master~2 de Mathématiques Pures}{Paris VI, Paris VII,
Paris XI, Polytechnique}{Algèbre et Géométrie}{Mention Très
Bien \footnotesize(Cours: 19.88/20, Mémoire de M2: 18/20, Total: 18.94/20)}{(Inscription pédagogique en 2004--2005.)
Mémoire de M2 sur la
« classification des groupes de réflexions complexes »,
superviseur: Michel Broué (Institut Henri Poincaré).}
\cventry{2004--2005}{Agrégation de Mathématiques}{}{option Calcul Scientifique}{Rang~9}{}
\cventry{2003--2007}{École Normale Supérieure}{Paris}{Concours Informatique}{Rang 1}{}
\subcventry{2003--2006}{Magistère de Mathématiques (MMFAI)}{}{Mention Très Bien}{}{}
\subcventry{2003--2004}{L3 et M1 de Mathématiques}{}{Mentions Très Bien %\footnotesize(L3: 19/20, Cours de M1: 18.67/20, Mémoire de M1: 14/20, Total du M1: 17/20)
}{}{
Validation de cours d'Informatiques de L3 et M1 en sus.
Mémoire de M1 sur « Modules de Clifford et $K$-théorie », réalisé avec Mehdi
Tibouchi, superviseur: François Pierrot.}
\cventry{2001--2003}{Classes préparatoires MPSI et MP*}{Lycée du Parc, Lyon}{}{}{}
\cventry{2000--2001}{Bac Scientifique spécialité Mathématiques}{Lycée René Descartes, Saint-Genis-Laval (69)}{mention Très Bien}{}{}
EOS
			Biblio.process_group(:experiences,@biblio, **kwds)+<<'EOS'
\section{Langages}
\cvlanguage{Français}{Natif}{}
\cvlanguage{Anglais}{Courant}{Séjour d'un an à Knoxville, dans le Tennessee}
\cvlanguage{Allemand}{Élémentaire}{9 ans de cours}

\section{Compétences informatiques}
\cvcomputer{Programation}{\small C, \textsc{Java}, Ocaml, Perl, PHP, Ruby, Shell}{OS}{Linux (Archlinux)}
\cvcomputer{Scientifique}{Magma, Matlab, Pari, Sage}{VCS}{Git, Mercurial, Subversion}
\cvcomputer{Web}{(X)HTML, CSS, Javascript}{Typographie}{\LuaLaTeX}

\section{Intérêts}
\cvline{Sport}{\small Cirque, Escalade, Raquettes.}
\cvline{Sécurité}{\small Formation premiers secours.}
\cvline{Divers}{\small Permis de conduire.}
EOS
		end
		#Separation
		r+=<<EOS
\\clearpage
\\hypertarget{appendix}{}
\\bookmark[level=0,dest=appendix]{#{midtitle}}
\\begin{center}
\\Huge #{midtitle}
\\end{center}
\\medskip

EOS
		#Partie Activités scientifiques
    r+=Biblio.process_group(groups,@biblio, **kwds)
	end
	return r
end

def generate(type, **kwds)
	lang=kwds[:lang]
	r=""
	case type
	when :all
		r+=header(:article,"List of all publications", bibfile: "perso,perso_fr", **kwds)
	when :publi
		case lang
		when :en
			r+=header(:article,"List of publications", **kwds)
		when :fr
			r+=header(:article,"Liste des publications", **kwds)
		end
	when :cv
		case lang
		when :en
			r+=header(:cv,"Researcher in cryptography", **kwds)
		when :fr
			r+=header(:cv,"Chargé de Recherche en cryptographie", **kwds)
		end
	end
	r+=main(type, **kwds)
	r+="\\end{document}\n"
	return r
end

def process(type, file, **kwds)
	f=Pathname.new(File.dirname(caller[0]))+"#{file.to_s}.tex"
	puts "- Writing to #{f.to_s}"
	data=generate(type, **kwds)
	f.write(data)
end

def run
	@biblio=Biblio.categorize(Biblio.load("./perso.yaml"))
	kwds={}
	process(:all,"all", out: :tex, lang: :fr, **kwds)
	process(:publi,"publications_damien_robert_fr", out: :texbib, lang: :fr, **kwds)
	process(:publi,"publications_damien_robert_en", out: :texbib, lang: :en, **kwds)
	process(:cv,"cv_damien_robert_fr", out: :texcv, lang: :fr, **kwds)
	process(:cv,"cv_damien_robert_en", out: :texcv, lang: :en, **kwds)
end

run
