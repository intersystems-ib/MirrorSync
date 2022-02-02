#!/bin/bash

echo "Start IRIS:"
iris start IRIS
echo "Execute IRIS setup"
iris session IRIS < /ISC/iris.script

echo "Stop IRIS"
iris stop IRIS quietly
exit 0
