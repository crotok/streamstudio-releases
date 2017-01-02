#!/bin/bash

trap '{ echo "Time to quit." ; exit 1 }' INT

log()  {
    if [ ${debug} -eq 1 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') !! $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') >> $1" >> ${error_log}
    fi
}

debug()  {
    if [ ${debug} -eq 1 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') >> $1"
    fi
}

debug=1
error_log="./updater.log"
echo -n "" > ${error_log}

base_url="https://download.streamstudio.cc/"
file_checker="update.html"

old_version_file="./old_version"
old_version=''

debug "Start checking StreamStudio version..."

if [ -f ${old_version_file} ]; then
    old_version=$(<${old_version_file})
fi

debug "Check version in: ${base_url}${file_checker}"
html=$(curl -sL ${base_url}${file_checker})

if [[ $? -ne 0 || "$html" == "" ]]; then
    log "Can't fetch current version: $?"
    exit 1
fi

current_version=`echo $html | sed -e 's/<[^>]*>//g' | tr -d '[:space:]'`

if [[ $? -ne 0 || "$current_version" == "" ]]; then
    log "Can't parse current version: $?"
    exit 1
fi

if [[ ! ${current_version} =~ ^[0-9]{1,2}(\.[0-9]{1,2}(\.[0-9]{1,2})?)?$ ]]; then
    log "Wrong current version format: $current_version"
    exit 1
fi

debug "Remote version: ${current_version} Local version: ${old_version}"

if [ "$current_version" == "$old_version" ]; then
    debug "Save version as old one. Exiting."
    exit 0
fi

debug "We have a new version. Creating folder for the ${current_version} version..."

if [[ -d "./releases/${current_version}" ]]; then
    log "The folder for version ${current_version} already exists. Exiting."
    exit 1
fi

mkdir "./releases/${current_version}"

if [[ ! -f "./releases/${current_version}/streamstudio-64.zip" ]]; then
    debug "Downloading x64 archive..."
    rm -rf "./releases/${current_version}/streamstudio-64.zip"
    curl -sL ${base_url}streamstudio-64.zip -o "./releases/${current_version}/streamstudio-64.zip"

    if [[ $? -ne 0 || ! -f "./releases/${current_version}/streamstudio-64.zip" ]]; then
        log "Can't download x64 version: $?"
        rm -rf "./releases/${current_version}/streamstudio-64.zip"
        exit 1
    fi
fi

if [[ ! -f "./releases/${current_version}/streamstudio-64.zip.sha256sum.txt" ]]; then
    debug "Calculating sha256sum for the x64 archive..."
    sha256sum "./releases/${current_version}/streamstudio-64.zip" > "./releases/${current_version}/streamstudio-64.zip.sha256sum.txt"
fi

if [[ ! -f "./releases/${current_version}/streamstudio-32.zip" ]]; then
    debug "Downloading x86 archive..."
    rm -rf "./releases/${current_version}/streamstudio-32.zip"
    curl -sL ${base_url}streamstudio-32.zip -o "./releases/${current_version}/streamstudio-32.zip"

    if [[ $? -ne 0 || ! -f "./releases/${current_version}/streamstudio-32.zip" ]]; then
        log "Can't download x86 version: $?"
        rm -rf "./releases/${current_version}/streamstudio-32.zip"
        exit 1
    fi
fi

if [[ ! -f "./releases/${current_version}/streamstudio-32.zip.sha256sum.txt" ]]; then
    debug "Calculating sha256sum for the x86 archive..."
    sha256sum "./releases/${current_version}/streamstudio-32.zip" > "./releases/${current_version}/streamstudio-32.zip.sha256sum.txt"
fi

git add ./releases/${current_version}/*
git commit -m "Bump to ${current_version}" ./releases/${current_version}/*
git push origin master

rm -rf ./releases/${current_version}/*

echo ${current_version} > ${old_version_file}
