<?php
/*
 +--------------------------------------------------------------------------+
 | This file is part of the Kolab Web Admin Panel                           |
 |                                                                          |
 | Copyright (C) 2011-2014, Kolab Systems AG                                |
 |                                                                          |
 | This program is free software: you can redistribute it and/or modify     |
 | it under the terms of the GNU Affero General Public License as published |
 | by the Free Software Foundation, either version 3 of the License, or     |
 | (at your option) any later version.                                      |
 |                                                                          |
 | This program is distributed in the hope that it will be useful,          |
 | but WITHOUT ANY WARRANTY; without even the implied warranty of           |
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the             |
 | GNU Affero General Public License for more details.                      |
 |                                                                          |
 | You should have received a copy of the GNU Affero General Public License |
 | along with this program. If not, see <http://www.gnu.org/licenses/>      |
 +--------------------------------------------------------------------------+
 | Author: Aleksander Machniak <machniak@kolabsys.com>                      |
 +--------------------------------------------------------------------------+
*/

set_time_limit(0);

require_once __DIR__ . '/../lib/functions.php';
require_once 'Auth/LDAP.php';

$LDAP = new LDAP();
$CONF = Conf::get_instance();

$username = $CONF->get('ldap', 'bind_dn');
$password = $CONF->get('ldap', 'bind_pw');
$domain   = $CONF->get('kolab', 'primary_domain');

// see https://cgit.kolab.org/webadmin/tree/lib/kolab_api_controller.php#n292
session_start();
$_SESSION['user'] = new User();
$_SESSION['user']->authenticate($username, $password, $domain);


// get list of domains to delete
$domains = list_deleted_domains();

if (empty($domains)) {
    die();
}

// delete domains
foreach ($domains as $dn => $domain) {
    delete_domain($dn, $domain);
}


function list_deleted_domains()
{
    global $LDAP, $CONF;

    $result = $LDAP->list_domains(
        array(
            'associateddomain',
            'inetdomainbasedn',
            'inetdomainstatus',
        ),
        array(
            'params' => array(
                'inetdomainstatus' => array(
                    'value' => 'deleted',
                    'type'  => 'exact',
                ),
            ),
        ),
        array(
            'page_size' => 999,
            'page'      => 1,
            'sort_by'   => 'associateddomain',
        )
    );

    return $result['list'];
}

function delete_domain($domain_dn, $domain)
{
    global $LDAP, $CONF;

    // get domain name
    $domain_name = $domain['associateddomain'];
    if (is_array($domain_name)) {
        $domain_name = array_shift($domain_name);
    }

    // sanity check
    if ($domain['inetdomainstatus'] != 'deleted') {
        echo "Domain $domain_name is not marked for deletion. Skipped.";
        return;
    }

    echo  date('Y-m-d') . ": Deleting domain $domain_name... ";

    if (!empty($domain['inetdomainbasedn'])) {
        $inetdomainbasedn = $domain['inetdomainbasedn'];
    }
    else {
        $inetdomainbasedn = "dc=" . implode(',dc=', explode('.', $domain_name));
    }

    // only deletes associateddomain=domain.tld,cn=kolab,cn=config
    if (!$LDAP->delete_entry($domain_dn)) {
        echo "Error: Failed to delete $domain_dn.\n";
        return;
    }

    $entries   = array();
    $entries[] = $inetdomainbasedn;

    $cn        = str_replace('.', '_', $domain_name);
    $entries[] = "cn={$cn},cn=ldbm database,cn=plugins,cn=config";

    $cn        = str_replace(array(',', '='), array('\2C', '\3D'), $inetdomainbasedn);
    $entries[] = "cn={$cn},cn=mapping tree,cn=config";

    foreach ($entries as $dn) {
        if (!$LDAP->delete_entry_recursive($dn)) {
            echo "Error: Failed to delete $dn.\n";
            return;
        }
    }

    echo "Done.\n";
}
