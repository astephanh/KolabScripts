#!/usr/bin/env python

import unittest
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from helperKolabWAP import KolabWAPTestHelpers

# assumes password for cn=Directory Manager is test.
# assumes that the initTBitsISP.sh script has been run.
# will create a domain admin user, with a maximum number of 3 accounts
# will create 2 new domains for this admin
# will create users inside that new domain
# will check that it fails to create a 5th account, across the domains
class KolabWAPDomainAdmin(unittest.TestCase):

    def setUp(self):
        self.kolabWAPhelper = KolabWAPTestHelpers()
        self.driver = self.kolabWAPhelper.init_driver()

    def test_max_accounts(self):
        kolabWAPhelper = self.kolabWAPhelper
        kolabWAPhelper.log("Running test: test_max_accounts")
        
        # login Directory Manager
        kolabWAPhelper.login_kolab_wap("/kolab-webadmin", "cn=Directory Manager", "test")

        username, emailLogin, password, domainname = kolabWAPhelper.create_domainadmin(
            max_accounts = 4)

        # create another domain, with domain admin
        domainname2 = kolabWAPhelper.create_domain(username)

        # create user accounts
        kolabWAPhelper.select_domain(domainname)
        kolabWAPhelper.create_user()
        kolabWAPhelper.create_user()
        kolabWAPhelper.select_domain(domainname2)
        username2, emailLogin2, password2 = kolabWAPhelper.create_user()
        # should fail, only 4 accounts allowed, including the domain admin
        kolabWAPhelper.create_user(expected_message_contains = "Cannot create another account")

        kolabWAPhelper.upgrade_user_to_domainadmin(username2, domainname, max_accounts = 7)
        # should still fail, because the minimum is used
        kolabWAPhelper.create_user(expected_message_contains = "Cannot create another account")

        kolabWAPhelper.logout_kolab_wap()

    def tearDown(self):
        
        # write current page for debugging purposes
        self.kolabWAPhelper.log_current_page()
        
        self.driver.quit()

if __name__ == "__main__":
    unittest.main()


