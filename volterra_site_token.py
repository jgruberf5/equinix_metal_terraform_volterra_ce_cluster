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


def assure_site_token(site, tenant):
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    context.verify_mode = ssl.CERT_NONE
    try:
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/tokens/%s" % (
            tenant, site)
        request = urllib.request.Request(
            url, method='GET')
        response = urllib.request.urlopen(request, context=context)
        return json.load(response)['system_metadata']['uid']
    except HTTPError as her:
        if her.code == 404:
            try:
                headers = {}
                url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/tokens" % tenant
                headers['volterra-apigw-tenant'] = tenant
                headers['content-type'] = 'application/json'
                data = {
                    "metadata": {
                        "annotations": {},
                        "description": "Site Authorization Token for %s" % site,
                        "disable": False,
                        "labels": {},
                        "name": site,
                        "namespace": "system"
                    },
                    "spec": {}
                }
                data = json.dumps(data)
                request = urllib.request.Request(
                    url=url, headers=headers, data=bytes(data.encode('utf-8')), method='POST')
                response = urllib.request.urlopen(request, context=context)
                site_token = json.load(response)
                return site_token['system_metadata']['uid']
            except HTTPError as err:
                sys.stderr.write(
                    "Error creating site token resources %s: %s\n" % (url, err))
                sys.exit(1)
        else:
            sys.stderr.write(
                "Error retrieving site token resources %s: %s\n" % (url, her))
            sys.exit(1)
    except Exception as er:
        sys.stderr.write(
            "Error retrieving site token resources %s\n" % er)
        sys.exit(1)


def destroy_site_token(site, tenant):
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    context.verify_mode = ssl.CERT_NONE
    try:
        context.load_cert_chain(certfile=CERT_FILE_NAME, keyfile=KEY_FILE_NAME)
        url = "https://%s.console.ves.volterra.io/api/register/namespaces/system/tokens/%s" % (
            tenant, site)
        request = urllib.request.Request(
            url, method='DELETE')
        urllib.request.urlopen(request, context=context)
        return True
    except HTTPError as her:
        if her.code != 404:
            sys.stderr.write(
                "Error deleting site token resources %s: %s\n" % (url, her))
            sys.exit(1)
    except Exception as er:
        sys.stderr.write(
            "Error deleting site token resources %s\n" % er)
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
        prog='volterra_site_token',
        usage='%(prog)s.py [options]',
        description='preforms Volterra API Site Token management'
    )
    ap.add_argument(
        '--action',
        help='action to perform: create or destroy',
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
    args = ap.parse_args()

    if args.action == "create":
        token_id = assure_site_token(args.site, args.tenant)
        site_token_file = "%s/%s_site_token.txt" % (
            os.path.dirname(os.path.realpath(__file__)), args.site)
        if os.path.exists(site_token_file):
            os.unlink(site_token_file)
        with open(site_token_file, "w") as site_token_file:
            site_token_file.write(token_id)

    if args.action == "destroy":
        destroy_site_token(args.site, args.tenant)
        site_token_file = "%s/%s_site_token.txt" % (
            os.path.dirname(os.path.realpath(__file__)), args.site)
        if os.path.exists(site_token_file):
            os.unlink(site_token_file)

    sys.exit(0)


if __name__ == '__main__':
    main()
