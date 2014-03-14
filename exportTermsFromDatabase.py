#!/sw/bin/python2.7
# -*- coding: utf-8 -*-
#####################
#
# © 2013 Autodesk Development Sàrl
#
# Created by Ventsislav Zhechev on 05 Nov 2013
#
# Changelog
# v0.1		Modified on 05 Nov 2013 by Ventsislav Zhechev
# Original version.
#
#####################


import sys, pymysql

import pprint


def connectToDB():
	return pymysql.connect(host="localhost", port=3307, user="root", passwd="Demeter7", db="Terminology_staging", charset="utf8")


conn = connectToDB()
cursor = conn.cursor(pymysql.cursors.DictCursor)
	
cursor.execute('select TermID, Term, ContentType, NewTo from TermList where JobID = %s or JobID = %s order by Term asc' % ('280', '292'))
terms = cursor.fetchall()
#pprint.PrettyPrinter(indent=2).pprint(terms)
for term in terms:
#	pprint.PrettyPrinter(indent=2).pprint(term)
	sys.stdout.write(term['Term'].encode("utf-8") + "\t \t" + term['ContentType'].encode("utf-8") + "\t" + term['NewTo'].encode("utf-8"))
	cursor.execute('select SourceContext from TermContexts where TermTranslationID = %s limit 20' % term['TermID'])
	contexts = cursor.fetchall()
#	pprint.PrettyPrinter(indent=2).pprint(contexts)
	for context in contexts:
		sys.stdout.write("\t" + context['SourceContext'].encode("utf-8"))
	sys.stdout.write("\n")
	
conn.close()