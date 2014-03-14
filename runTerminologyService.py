#!/sw/bin/python2.7
# -*- coding: utf-8 -*-
#####################
#
# © 2013 Autodesk Development Sàrl
#
# Created by Ventsislav Zhechev on 22 Oct 2013
#
# Changelog
# v0.1		Modified on 22 Oct 2013 by Ventsislav Zhechev
# Original version.
#
#####################

import sys, codecs, os, signal

#if sys.stdout.encoding != 'UTF-8':
#	sys.stdout = codecs.getwriter('utf-8')(sys.stdout, 'strict')
#if sys.stderr.encoding != 'UTF-8':
#	sys.stderr = codecs.getwriter('utf-8')(sys.stderr, 'strict')

sys.path.append("/Volumes/OptiBay/ADSK_Software/Terminology")
sys.path.append("/usr/lib/cgi-bin/Terminology")

from Terminology import Terminology, Service

signal.signal(signal.SIGINT, Service.cleanup)
signal.signal(signal.SIGTERM, Service.cleanup)

print u"Starting process with process ID: ", os.getpid()
print u"Starting server…"
#Terminology.run(debug=True, host='0.0.0.0', port=8080)
Terminology.run(host='0.0.0.0', port=8083)
