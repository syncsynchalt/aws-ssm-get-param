# aws-ssm-get-param

A shell script which can fetch params from AWS SSM without using awscli.

It currently depends on:

- `bash` - can be changed to `sh` if your shell's echo supports the `-n` flag
- `openssl` - for calculating `HMAC` and `SHA256`
- `curl` - for making web requests
- `python3` - for processing the json output

Substituting any of the dependencies for other dependencies is an exercise for the reader.

Share and enjoy!

### Usage

Common setup:

```
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=...
```

To fetch a non-encrypted parameter:

```
./aws-ssm-get-param.sh /foo/bar/baz
```

To fetch an encrypted parameter:

```
./aws-ssm-get-param.sh /foo/bar/baz decrypt
```
