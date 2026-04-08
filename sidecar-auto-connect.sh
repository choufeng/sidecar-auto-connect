#!/bin/bash
sleep 10
"$HOME/bin/sidecar-connect" --connect iPad >> /tmp/sidecar-connect.log 2>> /tmp/sidecar-connect.err
