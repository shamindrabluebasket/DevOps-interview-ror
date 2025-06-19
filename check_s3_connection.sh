#!/bin/bash

check_s3(){
aws s3 ls
if [[ $? -ne 0 ]];then
  echo "S3 connection failed"
  exit 1
else
  bundle exec rails server -b 0.0.0.0
fi
}

check_s3

exec "$@"