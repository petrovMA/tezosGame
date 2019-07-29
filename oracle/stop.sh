#!/usr/bin/env bash

pid=$( tail -n 1 app.rid )
kill $pid
rm -f app.rid
