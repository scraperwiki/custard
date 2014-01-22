#! /bin/bash
set -x
set -e

cd /opt/custard

date "+%H:%M:%S.%N"
cp -R /data/custard/node_modules .
date "+%H:%M:%S.%N"

npm install --unsafe-perm
source activate

echo Starting redis.
redis-server &

echo Starting mongo.
mkdir -p /data/db
mongod &

waitfor() {
	while ! nc -z localhost $1;
	do
		echo waiting for $2 $((i++))
		sleep 0.1
	done
}

waitfor 6379 redis
waitfor 27017 mongod

# cake dev &
# waitfor 3001 cake-dev

# echo "Sleeping for 20"
# sleep 20
# echo FILES = $(lsof | wc -l)

echo "Starting mocha..."
mocha test/unit
export S=$?

# TODO(pwaller/drj): Integration tests.

echo mocha exit status: $S
exit $S