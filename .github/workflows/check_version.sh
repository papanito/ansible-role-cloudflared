#!/bin/bash
if [ -z $(git describe --tags `git rev-list --tags` | grep `cat ./VERSION`$) ]
then
    echo Tag $(cat ./VERSION) not found, good to go
    exit 0
else
    echo Tag $(cat ./VERSION) already exists, bump version
    exit 1
fi