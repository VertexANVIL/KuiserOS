#!/usr/bin/env bash
set -e
umask 027
cd "$NFAST_HOME/log"
export PATH="$NFAST_HOME/bin:$PATH"
exec "$NFAST_HOME/sbin/raserv"
