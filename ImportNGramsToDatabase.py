#!/sw/bin/python2.7
# -*- coding: utf-8 -*-
#####################
#
# © 2013 Autodesk Development Sàrl
#
# Created by Ventsislav Zhechev on 31 Oct 2013
#
# Changelog
# v0.1		Modified on 31 Oct 2013 by Ventsislav Zhechev
# Original version.
#
#####################

import sys, signal

import pymysql

def connectToDB():
	return pymysql.connect(host="localhost", port=3307, user="root", passwd="Demeter7", db="Terminology", charset="utf8")

conn = connectToDB()
counter = 0

def cleanup(*args):
	conn.commit()
	conn.close()
	sys.stderr.write("Inserted %i nGrams\t" % counter)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

cursor = conn.cursor()
sql = "insert into nGrams(nGram) values "
#sql = "insert into nGramsCIV3D(nGram) values "

for line in sys.stdin:
	counter += 1
	sql += "('%s'), " % line.rstrip().replace("'", "''").replace("\\", "\\\\")
	if not counter % 25000:
#		sys.stderr.write(sql[:-2])
		cursor.execute(sql[:-2])
		conn.commit()
#		sql = "insert into nGramsCIV3D(nGram) values "
		sql = "insert into nGrams(nGram) values "
		sys.stderr.write("Inserted %i nGrams\t" % counter)
		
if counter % 10000:
	cursor.execute(sql[:-2])
	conn.commit()
	
sys.stderr.write("Inserted %i nGrams\t" % counter)
conn.close()
