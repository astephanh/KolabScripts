#!/usr/bin/python
# vim: sw=2 ts=2 expandtab:
#
# create hostmaster aliases
# by Stephan Helas
#
#
################################################################################

import sys, os
import copy
from subprocess import Popen, PIPE

hostmaster_mail = 'hostmaster@pp-nt.net'
alias_file = '/etc/postfix/virtual_alias_maps_manual.cf'

################################################################################

# read file
with open(alias_file) as f:
  old_aliases = f.read().splitlines()
new_aliases = copy.copy(old_aliases)

# get all domains
cmd = "/usr/sbin/kolab list-domains | grep '^[^ ]'"
p = Popen(cmd , shell=True, stdout=PIPE, stderr=PIPE)
out, err = p.communicate()
domains = out.rstrip().splitlines()
if len(domains) == 0 or domains[0].find('Primary') == -1:
  print "getting domains failed"
  print out,err
  sys.exit(1)
domains = domains[1:]

# delete old aliases
remove = []
for line in new_aliases:
  # ignore comments
  if line.find('#') == 0:
    continue

  domain,dest_email = line.split(' ',1)
  if '@' in domain:
    user,domain = domain.split('@')

    # only hostmaster user
    if not user == 'hostmaster':
      continue
  
    if not domain in domains:
        remove.append(line)
        continue
    if not dest_email == hostmaster_mail:
        remove.append(line)

for line in remove:
  new_aliases.remove(line)


# add new aliases
for line in domains:
  email = 'hostmaster@%s' % line
  if not '%s %s' % (email,hostmaster_mail) in new_aliases:
    new_aliases.append('%s %s' % (email, hostmaster_mail))

# write new file if something has changed
if not new_aliases == old_aliases:
  f = open(alias_file,"w")
  for line in new_aliases:
    f.write("%s\n" % line)
  f.close()
  os.system('postmap %s' % alias_file)

