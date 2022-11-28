#!/bin/bash -e

key="${AWS_ACCESS_KEY_ID}"
secret="${AWS_SECRET_ACCESS_KEY}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

verb=POST
uri="/"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
datestamp=$(date -u +%Y%m%d)
service=ssm
host="${service}.${region}.amazonaws.com"

if [ "x$1" = "x--help" -o "x$1" = "x-h" -o "x$1" = "x--usage" -o "x$1" = "x" ]; then
    echo "Usage: $0 param-name [\"decrypt\"]" 1>&2
    exit 1
fi

if [ "x$key" = "x" -o "x$secret" = "x" ]; then
    echo "Must set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY" 1>&2
    exit 1
fi

if [ "x$2" = "xdecrypt" ]; then
    payload='{"Name": "'"$(echo $1 | tr -dc /A-Za-z0-9._-)"'","WithDecryption":true}'
else
    payload='{"Name": "'"$(echo $1 | tr -dc /A-Za-z0-9._-)"'","WithDecryption":false}'
fi
payload_hash=$(echo -n "$payload" | openssl sha256)

set +e
read -r -d '' canonical_request << EOM
$verb
$uri

content-type:application/x-amz-json-1.1
host:$host
x-amz-content-sha256:$payload_hash
x-amz-date:$timestamp
x-amz-target:AmazonSSM.GetParameter

content-type;host;x-amz-content-sha256;x-amz-date;x-amz-target
$payload_hash
EOM

canon_hash=$(echo -n "$canonical_request" | openssl sha256)

read -r -d '' string_to_sign << EOM
AWS4-HMAC-SHA256
$timestamp
$datestamp/$region/$service/aws4_request
$canon_hash
EOM
set -e

function hmac_sign {
    # echo "signing [$1] with key [$2]" 1>&2
    echo -n "$1" | openssl sha256 -mac hmac -macopt hexkey:"$2"
}

hexkey=$(echo -n "AWS4$secret" | od -v -t x1 -A n | tr -d ' \n')
skey1=$(hmac_sign "$datestamp" "$hexkey")
skey2=$(hmac_sign "$region" "$skey1")
skey3=$(hmac_sign "$service" "$skey2")
skey4=$(hmac_sign "aws4_request" "$skey3")
signing_key=$skey4
sig=$(hmac_sign "$string_to_sign" "$signing_key")
auth_header="AWS4-HMAC-SHA256 Credential=$key/$datestamp/$region/$service/aws4_request,SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date;x-amz-target,Signature=$sig"

curl -s -X $verb https://$host$uri \
    -H "Content-Type: application/x-amz-json-1.1" \
    -H "Host: $host" \
    -H "Authorization: $auth_header" \
    -H "x-amz-content-sha256: $payload_hash" \
    -H "x-amz-date: $timestamp" \
    -H "x-amz-target: AmazonSSM.GetParameter" \
    -d "$payload" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data["Parameter"]["Value"])
'
