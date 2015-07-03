#!/usr/bin/env python
# vim: ts=2 sw=2  nu si:
import time
import datetime
import unittest
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from helperKolabWAP import KolabWAPTestHelpers


class KolabWAPCreateUser():
	def __init__(self):
		self.kolabWAPhelper = KolabWAPTestHelpers()
		self.driver = self.kolabWAPhelper.init_driver()

	def create_user(self,domainname,csv):
		kolabWAPhelper = self.kolabWAPhelper
		driver = self.driver

		user_template = "test"

		# login Directory Manager
		kolabWAPhelper.login_kolab_wap("/kolab-webadmin/", "cn=Directory Manager", "test")

		# create domainname
		if not kolabWAPhelper.select_domain(domainname):
			kolabWAPhelper.create_domain(domainname)
			kolabWAPhelper.log("domain created: %r" % domainname)

		# create User
		for count in csv:
			user_name = "%s%i" % (user_template, int(count))
			if not kolabWAPhelper.find_user(user_name):
				username, emailLogin, password = kolabWAPhelper.create_user(username=user_name)
			else:
				print "user %s found" % user_name

			#username, emailLogin, password = kolabWAPhelper.create_user()
			#kolabWAPhelper.log("User created: %r" % username)



	def __del__(self):
		kolabWAPhelper = self.kolabWAPhelper

		kolabWAPhelper.log("wrapping things up ...")
		kolabWAPhelper.logout_kolab_wap()
		self.driver.quit()


if __name__ == "__main__":
	csv_list = [1,2,3,4,5,6,7,8]
	domain = "test.ru"
	KolabWAPCreateUser().create_user(domain,csv_list)

