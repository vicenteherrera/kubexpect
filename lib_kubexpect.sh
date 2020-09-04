#!/bin/bash

set -euo pipefail

function wait_job_complete {
    job=$1
    echo "Waiting for job $job to complete"
    kubectl wait --for=condition=complete "job/${job}" --timeout=30s
    echo
}

function wait_job_exists {
    job_name=$1
    timeout=60
    echo "Wait for $job_name job's pod to exist, timeout $timeout s"
    _wait_for_command "kubectl get job -l app.kubernetes.io/name=$cronjob_name -o name" $timeout
    echo "$cronjob_name job's pod exists"
    echo
}

function check_secret_exists {
    _check_resource_exists secret $1
}

function get_cronjob_pod_name {
    cronjob_name=$1
    found=$(kubectl get job -l "app.kubernetes.io/name=$cronjob_name" -o name | head -n 1)
    echo $found
}

function wait_cronjob_pod_exists {
    cronjob_name=$1
    timeout=60
    echo "Wait for $cronjob_name cronjob's triggered pod to exist, timeout $timeout s"
    _wait_for_command "kubectl get job -l app.kubernetes.io/name=$cronjob_name -o name" $timeout
    echo "$cronjob_name cronjob's pod exists"
    echo
}

function  wait_cronjob_pod_succeed {
    cronjob_name="$1"
    echo "Wait for $cronjob_name cronjob's triggered pod to complete at least once"
    kubectl wait --for=condition=complete job -l "app.kubernetes.io/name=$cronjob_name" --timeout=30s
    echo
}

function check_cronjob_pod_suceeded {
    cronjob_name="$1"
    echo "Check for $cronjob_name cronjob's triggered pod succeeded"
    cpod=$(kubectl get pods --field-selector=status.phase=Succeeded -l "app.kubernetes.io/name=$cronjob_name" -o name | head -n 1)
    if [ -z "$cpod" ]; then
        echo "pod not found"
        exit 1
    fi
    echo "Found succeeded pod: $cpod"
    echo
}

function  check_pod_log_expected {
    cpod="$1"
    expected="$2"
    echo "Checking log for $cpod pod"
    last=$(kubectl logs "$cpod" | tail -n 2 )
    if [ "$last" != "$expected" ]; then
        echo "Last log lines of pod not what was expected"
        echo "Found:"
        echo "$last"
        echo "Expected:"
        echo "$expected"
        exit 1
    fi
    echo "Log is what was expected"
    echo
}

function check_pod_log_expected_pattern {
    cpod="$1"
    pattern="$2"
    echo "Checking log for $cpod pod"
    last=$(kubectl logs "$cpod" | tail -n 2 )
    if [[ ! "$last" =~ $pattern ]]; then
        echo "Last log lines of pod not what was expected"
        echo "Found:"
        echo "$last"
        echo "Expected pattern:"
        echo "$pattern"
        exit 1
    fi
    echo "Log is what was expected"
    echo
}

# Internal functions

function _check_resource_exists {
    type=$1
    name=$2
    echo "Check for ${type} ${name}"
    resource=$(kubectl get ${type} --field-selector="metadata.name=${name}" -o name)
    if [ -z "$resource" ]; then
        echo "${type} not found"
        exit 1
    fi
    echo "${type} found"
    echo
}

function _wait_for_command {
    command=$1
    timeout=${2:-"60"}
    t="$timeout"
    found=$($command)
    while [ "$t" -gt 0 ] && [ -z "$found" ]
    do
        echo -n "."
        t=$(expr "$t" - "1")
        sleep 1
        found=$($command)
    done
    [ "$t" -ne "$timeout" ] && echo
    if [ -z "$found" ]; then
        echo "**Error: Timed out waiting"
        exit 1
    fi
}