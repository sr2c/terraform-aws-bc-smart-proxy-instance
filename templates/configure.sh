#!/usr/bin/env bash

set -e

aws s3 cp s3://${bucket_name}/default /etc/nginx/sites-enabled/default

systemctl reload-or-restart nginx
