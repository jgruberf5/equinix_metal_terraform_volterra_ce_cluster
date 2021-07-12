#!/usr/bin/env python3
import sys
import os
import argparse
import urllib.request
import json
import ssl
import time

from OpenSSL import crypto
from urllib.error import HTTPError

PENDING_TIMEOUT = 300
PENDING_WAIT = 30

CERT_FILE_NAME = 'cert.pem'
KEY_FILE_NAME = 'key.pem'

# REGISGTRATION_STATES = [ 'NOTSET', 'NEW', 'APPROVED', 'ADMITTED', 'RETIRED', 'FAILED', 'DONE', 'PENDING', 'ONLINE', 'UPGRADING', 'MAINTENANCE' ]

COUNT_REGISTRATION_STATES = ['APPROVED', 'ADMITTED', 'ONLINE']


def extract_ssl_creds(pkcs12file, pkcs12password):
    if not os.path.exists(CERT_FILE_NAME):
        try:
            p12 = crypto.load_pkcs12(
                open(pkcs12file, 'rb').read(),
                bytes(pkcs12password, 'utf-8')
            )
            with open(CERT_FILE_NAME, 'w') as cf:
                cf.write(crypto.dump_certificate(crypto.FILETYPE_PEM,
                                                 p12.get_certificate()).decode('utf-8'))
            with open(KEY_FILE_NAME, 'w') as kf:
                kf.write(crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                                p12.get_privatekey()).decode('utf-8'))
        except Exception as ex:
            sys.stderr.write(
                "Can not can not extract PKI credentials: %s\n" % ex)
            sys.exit(1)


def get_registrations(site, tenant, token):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/registrations_by_site/%s" % (
        tenant, site)
    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        request = urllib.request.Request(
            url, method='GET')
        response = urllib.request.urlopen(request, context=context)
        return json.load(response)['items']
    except Exception as ex:
        sys.stderr.write(
            "Can not fetch site registrations for %s: %s\n" % (url, ex))
        sys.exit(1)


def approve_registration(tenant, token, name, namespace, state, passport, tunnel_type):
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/registration/%s/approve" % (
        tenant, name)
    data = {
        "namespace": namespace,
        "name": name,
        "state": state,
        "passport": passport,
        "connected_region": "",
        "tunnel_type": tunnel_type
    }
    data = json.dumps(data)
    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        request = urllib.request.Request(
            url=url, data=bytes(data.encode('utf-8')), method='POST')
        urllib.request.urlopen(request, context=context)
        return True
    except Exception as ex:
        sys.stderr.write(
            "could not approve registration for %s : %s\n" % (url, ex))
        return False


def delete_voltstack_site(site, tenant):
    # remove all Voltstack sites with this name
    url = "https://%s.console.ves.volterra.io/api/config/namespaces/system/voltstack_sites/%s" % (
        tenant, site)
    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        request = urllib.request.Request(
            url=url, method='DELETE')
        urllib.request.urlopen(request, context=context)
    except Exception as ex:
        sys.stderr.write(
            "Can not delete voltstack site %s: %s\n" % (url, ex))
        sys.exit(1)


def decomission_site(site, tenant):
    # remove all Voltmesh sites with this name
    url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/site/%s/state" % (
        tenant, site)
    data = {
        "namespace": "system",
        "name": site,
        "state": "DECOMMISSIONING"
    }
    data = json.dumps(data)
    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.verify_mode = ssl.CERT_NONE
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        request = urllib.request.Request(
            url=url, data=bytes(data.encode('utf-8')), method='POST')
        urllib.request.urlopen(request, context=context)
    except HTTPError as her:
        if her.code != 404:
            sys.stderr.write(
                "Can not delete site %s: %s\n" % (url, her))
            sys.exit(1)
    except Exception as ex:
        sys.stderr.write(
            "Can not delete site %s: %s\n" % (url, ex))
        sys.exit(1)


def main():
    pkcs12_file = os.getenv('VOLT_API_P12_FILE', None)
    pkcs12_password = os.getenv('VES_P12_PASSWORD', None)
    if pkcs12_file is None or pkcs12_password is None:
        sys.stderr.write(
            "Can not use Volterra APIs without VOLT_API_P12_FILE and VES_P12_PASSWORD environment being defined"
        )
        sys.exit(1)
    extract_ssl_creds(pkcs12_file, pkcs12_password)
    ap = argparse.ArgumentParser(
        prog='volterra_site_registration_actions',
        usage='%(prog)s.py [options]',
        description='preforms Volterra API node registrations and site delete actions'
    )
    ap.add_argument(
        '--action',
        help='action to perform: registernodes or sitedelete',
        required=True
    )
    ap.add_argument(
        '--site',
        help='Volterra site name',
        required=True
    )
    ap.add_argument(
        '--tenant',
        help='Volterra site tenant',
        required=True
    )
    ap.add_argument(
        '--token',
        help='Volterra API token',
        required=True
    )
    ap.add_argument(
        '--ssl',
        help='Allow SSL tunnels',
        required=False,
        default='true'
    )
    ap.add_argument(
        '--ipsec',
        help='Allow SSL tunnels',
        required=False,
        default='true'
    )
    ap.add_argument(
        '--masters',
        help='Cluster masters to register',
        required=False,
        default=1,
        type=int
    )
    ap.add_argument(
        '--size',
        help='Node(s) in cluster to register',
        required=False,
        default=1,
        type=int
    )
    ap.add_argument(
        '--delay',
        help='seconds to delay before processing',
        required=False,
        default=0,
        type=int
    )
    ap.add_argument(
        '--voltstack',
        help='Create Voltstack site',
        required=False
    )
    args = ap.parse_args()

    if args.action == "registernodes":
        if args.delay > 0:
            sys.stdout.write(
                "delaying polling for CE pending registrations for %d seconds..\n" % args.delay)
            sys.stdout.flush()
            time.sleep(args.delay)
        end_time = time.time() + PENDING_TIMEOUT
        counted_registrations = 0
        while (end_time - time.time()) > 0:
            registrations = get_registrations(
                args.site, args.tenant, args.token)
            if not registrations:
                sys.stdout.write(
                    "no registrations pending approval.. retrying in %d seconds.\n" % PENDING_WAIT)
                sys.stdout.flush()
                time.sleep(PENDING_WAIT)
            else:
                for reg in registrations:
                    if reg['object']['status']['current_state'] == "PENDING":
                        passport = reg['get_spec']['passport']
                        passport['tenant'] = reg['tenant']
                        passport['cluster_size'] = args.masters
                        tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC'
                        if args.ssl == 'true' and args.ipsec == 'true':
                            tunnel_type = 'SITE_TO_SITE_TUNNEL_IPSEC_OR_SSL'
                        elif args.ssl == 'true':
                            tunnel_type = 'SITE_TO_SITE_TUNNEL_SSL'
                        if approve_registration(args.tenant, args.token, reg['name'], reg['namespace'], 2, passport, tunnel_type):
                            sys.stdout.write("approved registration %s for node %s\n" % (
                                reg['name'], reg['get_spec']['infra']['hostname']))
                            counted_registrations = counted_registrations + 1
                    elif reg['object']['status']['current_state'] in COUNT_REGISTRATION_STATES:
                        counted_registrations = counted_registrations + 1
                    if counted_registrations == args.size:
                        sys.exit(0)
        sys.stderr.write(
            "no registrations pending approval after %d seconds.. giving up.\n" % PENDING_TIMEOUT)
        sys.stdout.flush()

    if args.action == "sitedelete":
        if args.voltstack == "true":
            delete_voltstack_site(args.site, args.tenant)
        else:
            decomission_site(args.site, args.tenant)

    sys.exit(0)


if __name__ == '__main__':
    main()
