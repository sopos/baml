#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: test.sh
#   Description: a test suite for YAml parser in pure baSH
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   YAml parser in pure baSH
#
#   Copyright © 2020 Dalibor Pospisil <sopos@sopos.eu>
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to
#   deal in the Software without restriction, including without limitation the
#   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
#   sell copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#   IN THE SOFTWARE.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. ./ya.sh

check_data() {
  local i res=0
  for i in "${!A[@]}"; do
    [[ "${A["$i"]}" == "${B["$i"]}" ]] || {
      yashLogError "A[$i]=${A["$i"]} != B[$i]=${B["$i"]}"
      res=1
    }
  done
  for i in "${!B[@]}"; do
    [[ "${B["$i"]}" == "${A["$i"]}" ]] || res=1
  done
  return $res
}

unset A
declare -A A
overall_result=0
test_number=0
check() {
  local res=0 B
  local tmp=`mktemp`
  unset B
  declare -A B
  let test_number++
  yash_parse B "$yaml_data" >$tmp 2>&1 || res=1
  [[ $res -eq 0 ]] && check_data || res=1
  [[ $res -eq ${1:-0} ]] && {
    yashLog "test $test_number${2:+": $2"}" "PASS "
  } || {
    yashLog "test $test_number${2:+": $2"}" "BEGIN"
    cat $tmp
    declare -p A B
    yashLog "test $test_number${2:+": $2"}" "FAIL "
    let overall_result++
  }
  rm -f $tmp
}

yaml_data='- g: a
b:
   - i
'
check 1


yaml_data='- >
  a   1
  b
-
  c: x
  x: y
- c: x
  x: y
-
 e
 f
-
 - e
 - f
- g:
  - a
  - h
  - i
'
check 1


yaml_data='- >
  a   1
  b
-
  c: x
  x: y
- c: x
  x: y
-
 e
 f
-
 - e
 - f
-
  - a
  - h
  - i
'
declare -A A=(
[0]='a   1 b
'
[1.c]="x"
[1.x]="y"
[2.c]="x"
[2.x]="y"
[3]="e f"
[4.0]="e"
[4.1]="f"
[5.0]="a"
[5.1]="h"
[5.2]="i"
)
check


yaml_data="
framework: beakerlib
tag:
- FedoraCI
- CI-Tier-1
- NoRHEL4
- NoRHEL5
- NoRHEL6
- SP-TBU
- TIPfail
- TIPfail_Security
- Tier1
- Tier1security
tags:
- generic
component:
- usbguard
contact:
- Dalibor Pospíšil <dapospis@redhat.com>
description: ''
recommend:
- usbguard
require:
- library(ControlFlow/Cleanup)
- library(ControlFlow/ConditionalPhases)
- beakerlib
summary: tries out valid and invalid config file keywords
test: ./runtest.sh
duration: 10m
environment:
    CONDITIONAL_PHASES_BL: 'only|both'
extra-nitrate: TC#0560519
extra-summary: CONDITIONAL_PHASES_BL=only|both /CoreOS/usbguard/Sanity/config-sanity
extra-task: /CoreOS/usbguard/Sanity/config-sanity
relevancy: |
    arch = s390x: False
    distro < rhel-7.6: False
path: /usbguard/Sanity/config-sanity
manual: false
enabled: true
result: respect
tier: null
name: /usbguard/Sanity/config-sanity/base
"
declare -A A=(
[framework]="beakerlib"
[tag.0]="FedoraCI"
[tag.1]="CI-Tier-1"
[tag.2]="NoRHEL4"
[tag.3]="NoRHEL5"
[tag.4]="NoRHEL6"
[tag.5]="SP-TBU"
[tag.6]="TIPfail"
[tag.7]="TIPfail_Security"
[tag.8]="Tier1"
[tag.9]="Tier1security"
[tags.0]="generic"
[component.0]="usbguard"
[contact.0]="Dalibor Pospíšil <dapospis@redhat.com>"
[description]="''"
[recommend.0]="usbguard"
[require.0]="library(ControlFlow/Cleanup)"
[require.1]="library(ControlFlow/ConditionalPhases)"
[require.2]="beakerlib"
[summary]="tries out valid and invalid config file keywords"
[test]="./runtest.sh"
[duration]="10m"
[environment.CONDITIONAL_PHASES_BL]="'only|both'"
[extra-nitrate]="TC#0560519"
[extra-summary]="CONDITIONAL_PHASES_BL=only|both /CoreOS/usbguard/Sanity/config-sanity"
[extra-task]="/CoreOS/usbguard/Sanity/config-sanity"
[relevancy]="arch = s390x: False
distro < rhel-7.6: False
"
[path]="/usbguard/Sanity/config-sanity"
[manual]="false"
[enabled]="true"
[result]="respect"
[tier]="null"
[name]="/usbguard/Sanity/config-sanity/base"
)
check


yaml_data='a:
- b
- c'
declare -A A=(
[a.0]='b'
[a.1]="c"
)
check


yaml_data='
---
- |
  asdfa
  dsf
-
'
declare -A A=(
[0]='asdfa
dsf
'
[1]='null'
)
check

echo _______________________________________________
[[ $overall_result -eq 0 ]] && {
  yashLog "overall result" "PASS "
  exit 0
} || {
  yashLog "overall result" "FAIL "
  exit 1
}
