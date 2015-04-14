#!/usr/bin/perl -w
#####################
#
# A utility to tokenise lines of text
#
# © 2011 Венцислав Жечев
# © 2011–2013 Autodesk Development Sàrl
#
# Created 07 May 2010 by Ventsislav Zhechev
#
# Changelog
# v1.2.9	Modified on 27 Jun 2013 by Ventsislav Zhechev
# Removed the code for handling product names, as this script was not the proper place for it.
#
# v1.2.8	Modified on 24 May 2013 by Ventsislav Zhechev
# Added code to attach the product name (if supplied at the end of the segment) to the end of each token.
#
# v1.2.7	Modified on 20 Nov 2012 by Ventsislav Zhechev
# Fixed a bug in URL handling where URLs could not be properly recognised under certain circumstances.
#
# v1.2.6
# Added a check that $. is defined and usable.
#
# v1.2.5
# Made a small modification to the handling of ‘.’, in particular in cases of alphabetical enumeration (eg. ‘A.’).
#
# v1.2.4
# Added prefix rules for all Autodesk languages.
# Improved the handling of prefixes.
#
# v1.2.3
# Added a prefix rule for English.
#
# v1.2.2
# Fixed a bug where Turkish data could not be handled properly.
#
# v1.2.1
# Added some configuration data to the progress output.
#
# v1.2
# Redesigned a large number of regular expressions, in particular the ones handling URLs and paths, as well as the ones handling apostrophies and quotes.
#
# v1.1
# Simplified some regular expressions by using Perl 5.10+ features.
#
# v1.0.3
# We are now removing all whitespace at the beggining and end of segments, not only plain space.
#
# v1.0.2
# Improved the status messages during tokeniser initialisation.
#
# v1.0.1
# Now we are properly excluding combining diacritical marks from the characters that count as tokenisation boundaries.
#
# v1.0
# Modified to be included in other Perl code in order to reduce the number of active Perl interpreters during regular operation.
#
# v0.9.4
# Improved prefix matching for cased data is available by lowercasing suspect material. A command line parameter is used to enable this functionality, by default expecting the data to be already in all lowercase.
#
# v0.9.3
# Added some possible German prefixes.
#
# v0.9.2
# Improved the treatment of non-space white space around special characters. In particular this doesn’t break \r characters within segments.
#
# v0.9.1
# Added prefixes for Turkish
#
# v0.9
# Fixed bugs with path names, colons, inch and feet marks
#
# v0.8
# Added specific handling for Korean and Japanese
# Fixed a bug with XML named entities
#
# v0.7
# Fixed a bug with numbers surrounded by braces
# Fixed a bug where the file-path-preserving rule would break the rule for ellipsis
#
# v0.5
# Cleared some bugs relating to braces, brackets and parentheses.
# Added treatment of file paths.
#
# v0.4
#
#####################

use strict;
use utf8;

sub initTokeniser {

my %prefixes = (
	cs =>
	{
		alt			=> 1,
		apod		=> 1,
		atd			=> 1,
		autom		=> 1,
		č				=> 1,
		co			=> 1,
		corp		=> 1,
		el			=> 1,
		hod			=> 1,
		hor			=> 1,
		inc			=> 1,
		konc		=> 1,
		kót			=> 1,
		max			=> 1,
		min			=> 1,
		mj			=> 1,
		např		=> 1,
		obr			=> 1,
		odkaz		=> 1,
		popř		=> 1,
		resp		=> 1,
		roz			=> 1,
		souč		=> 1,
		techn		=> 1,
		tj			=> 1,
		tol			=> 1,
		tř			=> 1,
		tzn			=> 1,
		tzv			=> 1,
		vert		=> 1,
		vč			=> 1,
		vs			=> 1,
		vyn			=> 1,
		vynáš		=> 1,
	},
	da =>
	{
		a				=> 1,
		bl			=> 1,
		"bl.a"	=> 1,
		ca			=> 1,
		co			=> 1,
		dvs			=> 1,
		eks			=> 1,
		evt			=> 1,
		f				=> 1,
		"f.eks"	=> 1,
		hhv			=> 1,
		inc			=> 1,
		misc		=> 1,
		osv			=> 1,
		pga			=> 1,
		pr			=> 1,
		vha			=> 1,
	},
	de =>
	{
		a				=> 1,
		ä				=> 1,
		abb			=> 1,
		abst		=> 1,
		akt			=> 1,
		alt			=> 1,
		anim		=> 1,
		"a.m"		=> 1,
		anord		=> 1,
		anz			=> 1,
		ausw		=> 1,
		autom		=> 1,
		b				=> 1,
		bem			=> 1,
		bzgl		=> 1,
		bzw			=> 1,
		ca			=> 1,
		co			=> 1,
		corp		=> 1,
		d				=> 1,
		dat			=> 1,
		"d.h"		=> 1,
		dr			=> 1,
		drehp		=> 1,
		e				=> 1,
		einf		=> 1,
		einst		=> 1,
		endp		=> 1,
		engl		=> 1,
		entf		=> 1,
		etc			=> 1,
		"e.v"		=> 1,
		evt			=> 1,
		evtl		=> 1,
		flg			=> 1,
		g				=> 1,
		gen			=> 1,
		geo			=> 1,
		geom		=> 1,
		ges			=> 1,
		gew			=> 1,
		ggf			=> 1,
		ggfs		=> 1,
		gr			=> 1,
		h				=> 1,
		hor			=> 1,
		horiz		=> 1,
		hr			=> 1,
		hydr		=> 1,
		i				=> 1,
		"id-nr"	=> 1,
		"i.d.r"	=> 1,
		indir		=> 1,
		inkl		=> 1,
		inc			=> 1,
		isol		=> 1,
		iter		=> 1,
		komb		=> 1,
		län			=> 1,
		lum			=> 1,
		ltd			=> 1,
		"m.a.p"	=> 1,
		mater		=> 1,
		max			=> 1,
		maxim		=> 1,
		mg			=> 1,
		min			=> 1,
		mind		=> 1,
		n				=> 1,
		navig		=> 1,
		"n.n"		=> 1,
		nr			=> 1,
		"n.v"		=> 1,
		"n.z"		=> 1,
		o				=> 1,
		"o.ä"		=> 1,
		obj			=> 1,
		od			=> 1,
		"o.g"		=> 1,
		pers		=> 1,
		"p.m"		=> 1,
		pos			=> 1,
		proz		=> 1,
		quat		=> 1,
		r				=> 1,
		ref			=> 1,
		s				=> 1,
		sklrg		=> 1,
		sog			=> 1,
		sq			=> 1,
		st			=> 1,
		std			=> 1,
		techn		=> 1,
		tol			=> 1,
		u				=> 1,
		"u.a"		=> 1,
		"u.s"		=> 1,
		umgek		=> 1,
		usw			=> 1,
		"u.u"		=> 1,
		v				=> 1,
		ver			=> 1,
		verkn		=> 1,
		vert		=> 1,
		vgl			=> 1,
		vorg		=> 1,
		vorh		=> 1,
		vs			=> 1,
		w				=> 1,
		win			=> 1,
		z				=> 1,
		"z.b"		=> 1,
		zeich		=> 1,
		zust		=> 1,
		zw			=> 1,
	},
	en =>
	{
		"a.m"		=> 1,
		"b.i.p"	=> 1,
		co			=> 1,
		corp		=> 1,
		deg			=> 1,
		diff		=> 1,
		"d.o.f"	=> 1,
		dr			=> 1,
		e				=> 1,
		"e.g"		=> 1,
		etc			=> 1,
		"e.v"		=> 1,
		gen			=> 1,
		horiz		=> 1,
		hr			=> 1,
		ie 			=> 1,
		"i.e"		=> 1,
		inc			=> 1,
		incl		=> 1,
		loc			=> 1,
		ltd			=> 1,
		mat			=> 1,
		max			=> 1,
		min			=> 1,
		mr			=> 1,
		ms			=> 1,
		"n.c"		=> 1,
		no			=> 1,
		"n.o"		=> 1,
		nov			=> 1,
		"n.v"		=> 1,
		oct			=> 1,
		p				=> 1,
		"p.m"		=> 1,
		"p.o.i"	=> 1,
		proj		=> 1,
		res			=> 1,
		resp		=> 1,
		segs		=> 1,
		st			=> 1,
		str			=> 1,
		temp		=> 1,
		"u.k"		=> 1,
		"u.s"		=> 1,
		"u.s.a"	=> 1,
		v				=> 1,
		vol			=> 1,
		vs			=> 1,
		"w.r.t"	=> 1,
	},
	es =>
	{
		admin		=> 1,
		agrup		=> 1,
		alm			=> 1,
		alt			=> 1,
		áng			=> 1,
		aplic		=> 1,
		arch		=> 1,
		autom		=> 1,
		calc		=> 1,
		co			=> 1,
		coef		=> 1,
		comp		=> 1,
		conec		=> 1,
		conf		=> 1,
		confg		=> 1,
		conj		=> 1,
		corp		=> 1,
		"c.v"		=> 1,
		def			=> 1,
		dept		=> 1,
		desf		=> 1,
		diám		=> 1,
		dib			=> 1,
		dir			=> 1,
		disp		=> 1,
		dist		=> 1,
		ee			=> 1,
		"ee.uu"	=> 1,
		ej			=> 1,
		etc			=> 1,
		etig		=> 1,
		"e.v"		=> 1,
		ext			=> 1,
		flr			=> 1,
		guard		=> 1,
		id			=> 1,
		ident		=> 1,
		impr		=> 1,
		inc			=> 1,
		inf			=> 1,
		info		=> 1,
		herr		=> 1,
		ltd			=> 1,
		máx			=> 1,
		mayús		=> 1,
		mín			=> 1,
		mov			=> 1,
		mr			=> 1,
		n				=> 1,
		"n.a"		=> 1,
		"n.c"		=> 1,
		"n.v"		=> 1,
		núm			=> 1,
		opc			=> 1,
		p				=> 1,
		"p.k"		=> 1,
		"p.m"		=> 1,
		props		=> 1,
		pto			=> 1,
		ref			=> 1,
		refer		=> 1,
		rep			=> 1,
		rest		=> 1,
		rot			=> 1,
		"r.s"		=> 1,
		segm		=> 1,
		sel			=> 1,
		selec		=> 1,
		sr			=> 1,
		sra			=> 1,
		st			=> 1,
		sup			=> 1,
		supr		=> 1,
		tam			=> 1,
		"t.e"		=> 1,
		"t.o"		=> 1,
		"t.s"		=> 1,
		unid		=> 1,
		"u.s"		=> 1,
		uu			=> 1,
		v				=> 1,
		val			=> 1,
		vent		=> 1,
		verif		=> 1,
		vol			=> 1,
		vs			=> 1,
	},
	fi =>
	{
		em			=> 1,
		esim		=> 1,
		inc			=> 1,
		jne			=> 1,
		ko			=> 1,
		ks			=> 1,
		mm			=> 1,
		ns			=> 1,
	},
	fr =>
	{
		abs			=> 1,
		accél		=> 1,
		adapt		=> 1,
		aff			=> 1,
		adj			=> 1,
		ajust		=> 1,
		align		=> 1,
		altér		=> 1,
		"a.m"		=> 1,
		amb			=> 1,
		anim		=> 1,
		arm			=> 1,
		attr		=> 1,
		auto		=> 1,
		autor		=> 1,
		basc		=> 1,
		calc		=> 1,
		cell		=> 1,
		cf			=> 1,
		chev		=> 1,
		circ		=> 1,
		co			=> 1,
		coef		=> 1,
		coeff		=> 1,
		col			=> 1,
		com			=> 1,
		comp		=> 1,
		conf		=> 1,
		conv		=> 1,
		coord		=> 1,
		corp		=> 1,
		coul		=> 1,
		couv		=> 1,
		déb			=> 1,
		décal		=> 1,
		déf			=> 1,
		défil		=> 1,
		défs		=> 1,
		deg			=> 1,
		dépl		=> 1,
		dépr		=> 1,
		dern		=> 1,
		dess		=> 1,
		dév			=> 1,
		dével		=> 1,
		diam		=> 1,
		diff		=> 1,
		dim			=> 1,
		dimen		=> 1,
		dir			=> 1,
		dist		=> 1,
		dr			=> 1,
		dyn			=> 1,
		elast		=> 1,
		elév		=> 1,
		emp			=> 1,
		enreg		=> 1,
		enrg		=> 1,
		ep			=> 1,
		epais		=> 1,
		etc			=> 1,
		étiq		=> 1,
		"e.v"		=> 1,
		ex			=> 1,
		ext			=> 1,
		fav			=> 1,
		"f.c"		=> 1,
		fen			=> 1,
		fich		=> 1,
		fig			=> 1,
		flott		=> 1,
		fric		=> 1,
		hab			=> 1,
		horiz		=> 1,
		ident		=> 1,
		"i.e"		=> 1,
		illum		=> 1,
		imp			=> 1,
		inc			=> 1,
		inf			=> 1,
		init		=> 1,
		int			=> 1,
		larg		=> 1,
		liss		=> 1,
		long		=> 1,
		ltd			=> 1,
		lum			=> 1,
		maj			=> 1,
		majus		=> 1,
		"m.a.p"	=> 1,
		mat			=> 1,
		matér		=> 1,
		max			=> 1,
		mél			=> 1,
		min			=> 1,
		mod			=> 1,
		modif		=> 1,
		mouv		=> 1,
		moy			=> 1,
		mult		=> 1,
		n				=> 1,
		nb			=> 1,
		nbr			=> 1,
		"n.c"		=> 1,
		niv			=> 1,
		"n.o"		=> 1,
		norm		=> 1,
		nouv		=> 1,
		num			=> 1,
		"n.v"		=> 1,
		obj			=> 1,
		obli		=> 1,
		opér		=> 1,
		p				=> 1,
		pan			=> 1,
		pann		=> 1,
		par			=> 1,
		param		=> 1,
		peint		=> 1,
		"p.ex"	=> 1,
		"p.m"		=> 1,
		po			=> 1,
		pos			=> 1,
		polyg		=> 1,
		press		=> 1,
		prim		=> 1,
		proj		=> 1,
		propr		=> 1,
		quad		=> 1,
		quadr		=> 1,
		quat		=> 1,
		qté			=> 1,
		rapp		=> 1,
		rech		=> 1,
		rect		=> 1,
		ref			=> 1,
		réf			=> 1,
		rel			=> 1,
		rempl		=> 1,
		réorg		=> 1,
		rep			=> 1,
		rép			=> 1,
		répét		=> 1,
		res			=> 1,
		rés			=> 1,
		résol		=> 1,
		ret			=> 1,
		rév			=> 1,
		rot			=> 1,
		roul		=> 1,
		segm		=> 1,
		sec			=> 1,
		sect		=> 1,
		sécur		=> 1,
		seg			=> 1,
		sél			=> 1,
		sélec		=> 1,
		sép			=> 1,
		somm		=> 1,
		spéc		=> 1,
		st			=> 1,
		stat		=> 1,
		sup			=> 1,
		supp		=> 1,
		supr		=> 1,
		suppr		=> 1,
		surf		=> 1,
		symb		=> 1,
		sync		=> 1,
		temp		=> 1,
		text		=> 1,
		tol			=> 1,
		traj		=> 1,
		trans		=> 1,
		uniq		=> 1,
		uniqu		=> 1,
		"u.s"		=> 1,
		util		=> 1,
		v				=> 1,
		val			=> 1,
		var			=> 1,
		vél			=> 1,
		vérif		=> 1,
		verr		=> 1,
		vis			=> 1,
		vit			=> 1,
		vol			=> 1,
		vs			=> 1,
	},
	hu =>
	{
		alt			=> 1,
		aut			=> 1,
		c				=> 1,
		co			=> 1,
		corp		=> 1,
		"e.v"		=> 1,
		függ		=> 1,
		geod		=> 1,
		igaz		=> 1,
		ill			=> 1,
		inc			=> 1,
		kb			=> 1,
		kivál		=> 1,
		köt			=> 1,
		ltd			=> 1,
		max			=> 1,
		min			=> 1,
		"n.v"		=> 1,
		pl			=> 1,
		stb			=> 1,
		szt			=> 1,
		táv			=> 1,
		ún			=> 1,
		"u.s"		=> 1,
		vízsz		=> 1,
	},
	it =>
	{
		agg			=> 1,
		ang			=> 1,
		calc		=> 1,
		co			=> 1,
		cod			=> 1,
		comp		=> 1,
		contr		=> 1,
		corp		=> 1,
		def			=> 1,
		dim			=> 1,
		direz		=> 1,
		dist		=> 1,
		"d.m"		=> 1,
		ecc			=> 1,
		elem		=> 1,
		es			=> 1,
		est			=> 1,
		"e.v"		=> 1,
		ident		=> 1,
		imp			=> 1,
		impil		=> 1,
		inc			=> 1,
		ipert		=> 1,
		largh		=> 1,
		ltd			=> 1,
		lungh		=> 1,
		"m.a.p"	=> 1,
		max			=> 1,
		min			=> 1,
		mr			=> 1,
		n				=> 1,
		"n.c"		=> 1,
		"n.o"		=> 1,
		norm		=> 1,
		nr			=> 1,
		num			=> 1,
		"n.v"		=> 1,
		ogg			=> 1,
		orizz		=> 1,
		"p.e"		=> 1,
		poll		=> 1,
		prod		=> 1,
		prog		=> 1,
		progr		=> 1,
		rappr		=> 1,
		rif			=> 1,
		risp		=> 1,
		selez		=> 1,
		sig			=> 1,
		spec		=> 1,
		spess		=> 1,
		st			=> 1,
		"u.s"		=> 1,
		v				=> 1,
		val			=> 1,
		vert		=> 1,
		vis			=> 1,
	},
	jp =>
	{
		"a.m"		=> 1,
		"b.i.p"	=> 1,
		calc		=> 1,
		co			=> 1,
		corp		=> 1,
		disp		=> 1,
		dr			=> 1,
		e				=> 1,
		"e.g"		=> 1,
		"e.v"		=> 1,
		gen			=> 1,
		hr			=> 1,
		inc			=> 1,
		ltd			=> 1,
		max			=> 1,
		min			=> 1,
		mr			=> 1,
		"n.c"		=> 1,
		"n.o"		=> 1,
		"n.v"		=> 1,
		"p.m"		=> 1,
		pos			=> 1,
		refl		=> 1,
		res			=> 1,
		spec		=> 1,
		st			=> 1,
		"u.k"		=> 1,
		"u.s"		=> 1,
		"u.s.a"	=> 1,
		v				=> 1,
		visib		=> 1,
		vs			=> 1,
	},
	ko =>
	{
		co			=> 1,
		col			=> 1,
		corp		=> 1,
		dr			=> 1,
		"e.v"		=> 1,
		in			=> 1,
		inc			=> 1,
		ltd			=> 1,
		max			=> 1,
		mt			=> 1,
		"n.c"		=> 1,
		"n.o"		=> 1,
		"n.v"		=> 1,
		st			=> 1,
		"u.s"		=> 1,
		v				=> 1,
		vol			=> 1,
		vs			=> 1,
	},
	nl =>
	{
		co			=> 1,
		"d.w.z"	=> 1,
		inc			=> 1,
		misc		=> 1,
		nr			=> 1,
		"o.a"		=> 1,
		vs			=> 1,
	},
	no =>
	{
		co			=> 1,
		dvs			=> 1,
		"f.eks"	=> 1,
		inc			=> 1,
		maks		=> 1,
		misc		=> 1,
		nr			=> 1,
		osv			=> 1,
	},
	pl =>
	{
		ang			=> 1,
		baz			=> 1,
		co			=> 1,
		dług		=> 1,
		dot			=> 1,
		ds			=> 1,
		godz		=> 1,
		ident		=> 1,
		inc			=> 1,
		itd			=> 1,
		itp			=> 1,
		jedn		=> 1,
		jęz			=> 1,
		kotw		=> 1,
		maks		=> 1,
		min			=> 1,
		"m.in"	=> 1,
		np			=> 1,
		nr			=> 1,
		nt			=> 1,
		obl			=> 1,
		ok			=> 1,
		opr			=> 1,
		p				=> 1,
		pkt			=> 1,
		płaszcz	=> 1,
		"p.n.e"	=> 1,
		pom			=> 1,
		pow			=> 1,
		przyp		=> 1,
		pt			=> 1,
		r				=> 1,
		rep			=> 1,
		rys			=> 1,
		sek			=> 1,
		st			=> 1,
		std			=> 1,
		szer		=> 1,
		tabl		=> 1,
		tel			=> 1,
		temp		=> 1,
		tj			=> 1,
		tzw			=> 1,
		ukł			=> 1,
		"u.s"		=> 1,
		ust			=> 1,
		utw			=> 1,
		w				=> 1,
		war			=> 1,
		wer			=> 1,
		wido		=> 1,
		wł			=> 1,
		wprow		=> 1,
		wsp			=> 1,
		współ		=> 1,
		wył			=> 1,
		wzgl		=> 1,
		zdef		=> 1,
		zob			=> 1,
	},
	pt_br =>
	{
		"a.c"		=> 1,
		descr		=> 1,
		etc			=> 1,
		inc			=> 1,
		ltd			=> 1,
		máx			=> 1,
		mín			=> 1,
		pol			=> 1,
		qt			=> 1,
		qtde		=> 1,
		snap		=> 1,
		st			=> 1,
		"u.s"		=> 1,
		vs			=> 1,
	},
	ru =>
	{
		co			=> 1,
		corp		=> 1,
		e				=> 1,
		"e.v"		=> 1,
		inc 		=> 1,
		ltd			=> 1,
		"n.c"		=> 1,
		"n.o"		=> 1,
		st			=> 1,
		"u.s"		=> 1,
		v				=> 1,
		аним		=> 1,
		вкл			=> 1,
		выс			=> 1,
		г				=> 1,
		гл			=> 1,
		д				=> 1,
		дв			=> 1,
		др			=> 1,
		е				=> 1,
		ед			=> 1,
		зум			=> 1,
		исп			=> 1,
		к				=> 1,
		касат		=> 1,
		кв			=> 1,
		кол			=> 1,
		куб			=> 1,
		макс		=> 1,
		мин			=> 1,
		натур		=> 1,
		обоз		=> 1,
		п				=> 1,
		парам		=> 1,
		поз			=> 1,
		польз		=> 1,
		пп			=> 1,
		пр			=> 1,
		расш		=> 1,
		рис			=> 1,
		с				=> 1,
		см			=> 1,
		стр			=> 1,
		т				=> 1,
		табл		=> 1,
		"т.д"		=> 1,
		"т.е"		=> 1,
		тел			=> 1,
		"т.к"		=> 1,
		"т.п"		=> 1,
		"т.ч"		=> 1,
		умолч		=> 1,
		фикс		=> 1,
		функц		=> 1,
		ч				=> 1,
		эфф			=> 1,
		эл			=> 1,
	},
	sv =>
	{
		"bl.a"	=> 1,
		co			=> 1,
		"d.v.s"	=> 1,
		inc			=> 1,
		"p.g.a"	=> 1,
		"s.k"		=> 1,
		"t.ex"	=> 1,
		ut			=> 1,
	},
	tr =>
	{
		"a.b.d"	=> 1,
		adr			=> 1,
		"a.i.r"	=> 1,
		avus		=> 1,
		bağ			=> 1,
		bağl		=> 1,
		bğl			=> 1,
		bil			=> 1,
		bilg		=> 1,
		bkz			=> 1,
		cm			=> 1,
		co			=> 1,
		corp		=> 1,
		değ			=> 1,
		değiş		=> 1,
		"doğ"		=> 1,
		dr			=> 1,
		eşitl		=> 1,
		geç			=> 1,
		"g.e.t"	=> 1,
		gör			=> 1,
		gün			=> 1,
		hop			=> 1,
		"il.kr"	=> 1,
		ilt			=> 1,
		inc			=> 1,
		inç			=> 1,
		kap			=> 1,
		kar			=> 1,
		kul			=> 1,
		kull		=> 1,
		ltd			=> 1,
		maks		=> 1,
		mik			=> 1,
		min			=> 1,
		mod			=> 1,
		n				=> 1,
		nk			=> 1,
		no			=> 1,
		nok			=> 1,
		örn			=> 1,
		ort			=> 1,
		"o.s.t"	=> 1,
		oto			=> 1,
		prog		=> 1,
		prot		=> 1,
		pt			=> 1,
		sağ			=> 1,
		sn			=> 1,
		st			=> 1,
		tanım		=> 1,
		tel			=> 1,
		ulusl		=> 1,
		"u.s"		=> 1,
		uyg			=> 1,
		uzun		=> 1,
		vb			=> 1,
		vs			=> 1,
	},
	vi =>
	{
		inc			=> 1,
		co			=> 1,
	},
	zh_hans =>
	{
		"a.m"		=> 1,
		"b.i.p"	=> 1,
		co			=> 1,
		corp		=> 1,
		"d.o.f"	=> 1,
		dr			=> 1,
		e				=> 1,
		"e.v"		=> 1,
		inc			=> 1,
		ltd			=> 1,
		"m.a.p"	=> 1,
		no			=> 1,
		"p.o.i"	=> 1,
		"p.m"		=> 1,
		refl		=> 1,
		st			=> 1,
		"u.s"		=> 1,
		v				=> 1,
		vs			=> 1,
	},
	zh_hant =>
	{
		co			=> 1,
		corp		=> 1,
		deg			=> 1,
		"e.v"		=> 1,
		hr			=> 1,
		inc			=> 1,
		ltd			=> 1,
		"n.v"		=> 1,
		"u.s"		=> 1,
		v				=> 1,
	},
);

my $language = "en";
if ($_[0]) {
	$language = $_[0];
	$language =~ s/[-_].*$//;
	$language = lc $language;
	$prefixes{$language} = $prefixes{"en"} unless defined($prefixes{$language});
}
print STDERR "Tokeniser initialised for language $language.\n";

my $lowercase = $_[1] || 0;
print STDERR "Lowercasing of prefixes enabled for language $language.\n" if $lowercase;
	
	return {
					prefixes	=> $prefixes{$language},
					language	=> $language,
					lowercase	=> $lowercase,
	};
}

sub tokenise {
	my ($id, $line) = @_;
	
	if (defined $.) {
		print STDERR "." if !($.%10000);
		print STDERR "[tok $id->{language}".($id->{lowercase} ? " lc" : "").": $.]" if !($.%500000);
	}
	
#	my $product;
#	($line, $product) = split /◊/, $line;
#	$product ||= "";
	
	# Korean specific
	$line =~ s/([\d\p{Script:Latin}])([\p{Script:Hangul}])/$1 $2/g if $id->{language} eq "ko";
	
	# Japanese specific
	if ($id->{language} eq "jp") {
		my $japanese = '[\p{Script:Hiragana}\p{Script:Katakana}\p{Block:Katakana_Phonetic_Extensions}\p{Block:CJK_Unified_Ideographs}\p{Block:CJK_Unified_Ideographs_Extension_A}\x{30FB}\x{30FC}]';
		$line =~ s/([\p{Script:Latin}])($japanese)/$1 $2/g;
	}

	#Unfortunately, most special characters need individual treatment.
	$line =~ s/([^\p{IsAlnum}\s\.\'\,\-\&\{\}\$\*\\’”\_\<\>\=\*\"\[\]\/\?;\@:%\#\(\)\`\p{InCombiningDiacriticalMarks}])/ ◊$1◊ /g;
	
	if ($line =~ /\./) {
		#Keep multiple periods together (eg. in ellipses). Separate them from surrounding data, unless they are part of a path.
		$line =~ s!(^|[^\.])(\.{2,}+)([^\.]|$)!my ($b, $r, $a) = ($1, $2, $3); $r =~ s/\./◊./g; ($b =~ /[\/\\]/ ? $b : "$b ")."$r◊".($a =~ /[\/\\]/ ? $a : " $a")!ge;
		#Process ‘.’.
		my $abbreviation = '(?<p>\p{IsAlpha}[\p{IsAlpha}\.\-]{0,4})\.(?![◊\w\.])';
		if ($id->{lowercase}) {
			if ($id->{language} eq 'tr') {
				$line =~ s/$abbreviation/my $p = $+{p}; $p =~ tr[İI][iı]; $id->{prefixes}{lc $p} ? "$p.◊ " : "$p ◊.◊ "/ge;
			} else {
				$line =~ s/$abbreviation/$id->{prefixes}{lc $+{p}} ? "$+{p}.◊ " : "$+{p} ◊.◊ "/ge;
			}
		} else {
			$line =~ s/$abbreviation/$id->{prefixes}{$+{p}} ? "$+{p}.◊ " : "$+{p} ◊.◊ "/ge;
		}

		#Protect ‘.’ at beginning of text (will usually be a file extension)
		$line =~ s/\.(\p{IsAlpha}+)/◊.◊$1◊/g;
	}

	if ($line =~ /:/) {
		#Don’t separate ‘:’ when inside numerals (eg. times).
		$line =~ s/(\d+):(\d+)/◊$1◊:◊$2◊/g;
		#Preserve Windows drive-letter syntax
		$line =~ s/(?<=\W)(\p{IsAlpha}):/$1◊:◊/g;
		#Handle ‘:’ in index entries
		$line =~ s/^([^\p{Punctuation}])([\s\w]{2,})(?<!◊):(?=\w)/$1$2 ◊:◊:◊ /g;
	}

	#Keep multiple special characters together.
	$line =~ s/(?<!\w)(?<s>(?<c>[*=_<>?-])\g{c}+)(?!\w)/ ◊$+{s}◊ /g;
	
	#Separate WS placeholders
	$line =~ s/(\{\d+\})/ ◊$1◊ /g;

	#Handle single terms in parentheses
	$line =~ s/(^|\s+)\(([◊\.\_\w]{2,}+)\)((?:\p{Punctuation}*[\s◊]+)|$)/$1◊(◊ $2 ◊) $3/g if $line =~ /\(/;

	if ($line =~ m![/\\]!) {
		#Preserve file paths
		$line =~ s/(^|[\s◊]+)([\p{IsAlnum}({\[<\\\/])((?:[^ \\\/]++[\\\/]++)+[^ \\\/]*)([*\$\p{IsAlnum})}\/\\>\]])(?=[\p{Punctuation}\s◊]|$)/
			my ($fs, $b, $d, $e) = ($1, $2, $3, $4);
			$b = "◊(◊ " if $b eq "(";
			$e = " ◊)◊" if $e eq ")";
			$d = "$b$d$e";
			if ($d =~ m![\\\/]!) {
				$d =~ s!([._\/\\:*+?=<>\[\](){}-])!◊$1◊!g
			} else {
				$d =~ s!([._:*+?=<>\[\](){}-])! ◊$1◊ !g
			}
			"$fs◊$d◊"
		/ge;
		#Separate double terms separated by a / except for number fractions
		$line =~ s/(^|[\s-]+)◊*(\d++[\'\"]?)◊*\/◊*(\d++[\'\"]?)◊*(?=[\s\p{Punctuation}]+|$)/$1◊$2‹\/›$3◊/g;
		$line =~ s/(^|\s+)([\p{IsAlnum}\p{InCombiningDiacriticalMarks}◊]++)\/([\p{IsAlnum}\p{InCombiningDiacriticalMarks}◊]++)(?=[\s\p{Punctuation}]+|$)/$1$2 ◊\/◊ $3/g;
		$line =~ s/[‹›]/◊/g;
	}
	
	$line =~ s/(?<!◊)([\$\?\[\]\(])(?!◊)/ ◊$1◊ /g;
	
	#Keep multiple special characters together again.
	$line =~ s/(?<=\w)(?<s>(?<c>[*=_<>?-])\g{c}+)(?=\w)/ ◊$+{s}◊ /g;
	
	if ($line =~ /,/) {
		#Separate commas, except when inside numerals.
		$line =~ s/([^\d,]+?),([^\d,]+?)/$1 ◊,◊ $2/g;
		$line =~ s/(\d+?),(?!\d+)/$1 ◊,◊ /g;
		$line =~ s/(,{2,})/ ◊$1◊ /g;
	}
	
	#Separate option names from option values.
	$line =~ s/(^|\s+)(\w+\=\s*)\"(\s*+[\p{IsAlnum}\s\-\._&;\']+?\s*)\"/my ($p, $l, $v) = ($1, $2, $3); $v =~ m!\s+! ? "$p$l◊ ◊\"◊ $v ◊\"◊ " : "$p$l◊ ◊\"$v\"◊ "/ge if $line =~ /\"/;
	
	#Process ‘{’ and ‘}’, taking care not to destroy {\… tags.
	$line =~ s/(?<!◊)(\{(\\[\w\\]+)?|\})(?!◊)/ ◊$1◊ /g;
	
	#Process ‘&’ and ‘;’, keeping named entities (&…;) intact.
	$line =~ s/\&\&/&/g;
	$line =~ s/(\&\w[◊\w]*?;)/ ◊$1◊ /g;
	$line =~ s/(\w+)\&(\w+)/$1$2/g; #remove Windows hotkey &
	$line =~ s/\&(?!\w[◊\w]*?;◊)/ ◊&◊ /g;
	$line =~ s/(?:^|\s+)(?<!◊\&)(\w+)(;)/ $1 ◊$2◊ /g;
	$line =~ s/(?<!◊);(?!◊)/ ; /g;
	
	#Only separate ‘)’ when it is not part of enumeration (eg. ‘3)’ or ‘--)’).
	$line =~ s/(^|\(.*?\s+)(\d+)\)/my ($s, $d) = ($1, $2); $s =~ m!\)! ? "$s $d)◊" : "$s $d ◊)◊"/ge;
	$line =~ s/(?:^|\s+)(-+)\)(?=\s*\w+)/ $1)◊/g;
	$line =~ s/(\w+ ?\d*)\)(?!◊)/$1 ◊)◊ /g;
#	$line =~ s/(\(◊*\s*[\p{IsAlnum}\s\-\/\\\,]+?)\)/$1 ◊)◊ /g;
	$line =~ s/\)(?!◊)/ ◊)◊ /g;
	
	#Process ‘:’ 
	$line =~ s/(?<!◊):(?![\/\\◊])/ ◊:◊ /g;
	
	#Process ‘<’.
	$line =~ s/(?<!◊)(\<)(?!\<*◊)/ ◊$1◊ /g;
	
	#Process ‘/>’ tag closing sequence.
	$line =~ s!(/\>)! ◊$1◊ !g;
	#Separate all remaining ‘>’.
	$line =~ s/(?<!◊)\>(?!\>*◊)/ ◊>◊ /g;

	#Separate ‘.’ at end of numerals.
	$line =~ s/(\d+?)\.(?![\w\d]+)/$1 ◊.◊ /g;
	#Readjoin ‘.’ in case of enumerations (eg. ‘5.’).
	$line =~ s/(^|[^◊\,\w\s]+\s+)(\d+) ◊\.◊ (?=\w+)/$1$2.◊ /g;
	#Readjoin ‘.’ in case of alphabetical enumerations (eg. ‘A.’).
	$line =~ s/(^|[^◊\,\w\s]+\s+)(\p{IsAlpha}) ◊\.◊ (?=\w+)/$1$2.◊ /g;
	#Separate all remaining ‘.’.
	$line =~ s/(?<![◊\.])\.(?!\.*[\w◊])/ ◊.◊ /g;
	
	#Separate the remaining ‘*’, ‘=’, ‘-’, ‘_’
	$line =~ s/\*(?![\*◊]*◊)/ ◊\*◊ /g;
	$line =~ s/(?<!◊)=(?![=◊]*◊)/ ◊=◊ /g;
	$line =~ s/-(?![-◊]*[\w\)◊])/ ◊-◊ /g;
	$line =~ s/_(?![_◊]*[\w◊])/ ◊_◊ /g;
	
	
	#Separate multiple single quotes.
	$line =~ s/([\'\`]{2,})/ ◊$1◊ /g; #`
	
	#Protect single quotes as feet marks and double quotes as inch marks
	$line =~ s/(?<!\w)(-?\d*[.\/◊]?\d+)◊*([\"”\'’‘])([◊\/]{0,2}(?:[\s\p{Punctuation}]+|$))/◊$1$2◊$3◊/g;

	#Separate double quotes.
	$line =~ s/([\\◊]?[\"”])(?!◊)/ ◊$1◊ /g;
	$line =~ s/(^|[^\d◊]+?)([\"”])(?!◊)/$1 ◊$2◊ /g;
	#Process single quotes in contractions.
	$line =~ s/(\p{IsAlnum}+)([\'’])(\p{IsAlpha}+)/($id->{language} eq "fr" || $id->{language} eq "it") ? "$1◊$2◊ $3" : (($id->{language} eq "en" || $id->{language} eq "de") ? "$1 ◊$2◊$3" : "$1 ◊$2◊ $3" )/ge;
	$line =~ s/(\s+)([\'’])(\p{IsAlpha}+)/(($id->{language} eq "en" || $id->{language} eq "de") && $3 eq "s") ? "$1◊$2◊$3" : "$1◊$2◊ $3"/ge;
	
	#If the character following the apostrophy is a digit, the apostrophy is most probably a foot makr or an hour mark.
	$line =~ s/([\'’])(?=[\p{IsAlpha}\s]|$)/ ◊$1◊ /g;
	
	$line =~ s/\`(?!\`*◊)/ ◊`◊ /g;
	
	#Process ‘@’ outside e-mail addresses.
	$line =~ s/(?<!\p{IsAlnum})@/ ◊@◊ /g;
	$line =~ s/@(?![\p{IsAlnum}◊])/ ◊@◊ /g;
	
	#Reattach brackets and parentheses around single numerals.
	$line =~ s/◊+([\(\[])◊+ +(\d+) +◊+([\)\]])◊+/◊$1$2$3◊/g;
	
	#Reattach parentheses around copyright and reserved symbols ‘(c)’ and ‘(r)’.
	$line =~ s/◊+\(◊+ +([CcRr]) +◊+\)◊+/◊\($1\)◊/g;
	
	#Reattach parentheses after beginning-of-line single letters and digits.
	$line =~ s/^\s*([\p{IsAlnum}])[\s◊]*\)◊*(\s+)/$1\)◊$2/g;

	#Clean up.
	$line =~ s/◊//g;
	$line =~ s/@ (\d+) < (\d+)/\@$1<$2/g;
	$line =~ s/^\s+|\s+$//g;
	$line =~ s/(\s{2,})/my $s = $1; $s =~ m![^ ]! ? ($s =~ s! *!!g) : ($s = ' '); $s/ge;
	
#	#Add product code to each token
#	$line =~ s/(\s|$)/◊$product$1/g if $product;

	return $line;
}

1;