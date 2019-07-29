#!/usr/bin/env bash

pid=$( tail -n 1 app.rid )
kill $pid
rm -f app.rid
setsid java -jar tezos-oracle.one-jar.jar & echo $! >> app.rid