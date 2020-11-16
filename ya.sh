#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: ya.sh
#   Description: YAml parser in pure baSH
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

yashLog() {
  printf ":: [ %(%T)T ] :: [ %s ] :: " -1 "${2:-" LOG "}" >&2
  echo -e "$1" >&2
}

yashLogDebug() {
  [[ -n "$DEBUG" ]] && yashLog "${FUNCNAME[1]}(): $1" "DEBUG"
}

yashLogError() {
  yashLog "${FUNCNAME[1]}(): $1" "ERROR"
}

yash_get_next() {
  local line IFS=$'\n' buffer_item type_name="$1" item_name="$2" yaml_data_name="$3"
  [[ -z "${!yaml_data_name}" ]] && return 1
  {
    read -r line
    buffer_item="$line"$'\n'
    if [[ "${line:0:1}" == '-' ]]; then
      yashLogDebug "detected list item '$line'"
      eval "$type_name='index'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[ "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    else
      yashLogDebug "detected associative array item '$line'"
      eval "$type_name='key'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[  "${line:0:1}" == "-" || "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    fi
  } <<< "${!yaml_data_name}"
  eval "${item_name}=\"\${buffer_item::-1}\""
  eval "${yaml_data_name}=\"\${buffer_rest::-1}\""
}

yash_clean() {
  # remove comments
  local line IFS=$'\n' buffer
  while read -r line; do
    [[ "$line" == "---" ]] && {
      buffer=''
      continue
    }
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    buffer+="$line"$'\n'
  done <<< "$1"
  echo -n "$buffer"
}

yash_parse_item() {
  local IFS=$'\n' line buffer type_name="$1" key_name="$2" val_name="$3" item="$4" type
  {
    read -r line
    if [[ "${line:0:1}" == "-" ]]; then
      eval "$key_name=''"
      yashLogDebug "detected list item '${!key_name}'"
      type='list'
      buffer=" ${line:1}"$'\n'
    elif [[ "$line" =~ ^([^:]*):(.*) ]]; then
      eval "$key_name=\"\${BASH_REMATCH[1]}\""
      yashLogDebug "detected associative array item '${!key_name}'"
      type='array'
      buffer="${BASH_REMATCH[2]}"$'\n'
    else
      yashLogError "could not parse item '$line'"
      return 1
    fi
    while read -e line; do
      buffer+="${line}"$'\n'
    done
  } <<< "$item"
  eval "$val_name=\"\${buffer::-1}\""
  yashLogDebug "  with value '${!val_name}'"
  if [[ "$type" == "list" ]]; then
    yash_sanitize_value "${type_name}" "${val_name}" || return 1
  elif [[ "$type" == "array" ]]; then
    yash_sanitize_array_value "${type_name}" "${val_name}" || return 1
  else
    yashLogError "unexpected item type"
  fi
}

yash_sanitize_array_value() {
  yashLogDebug "sanitize array value"
  local IFS=$'\n' line buffer type_name="$1" val_name="$2" indent
  read -r line <<< "${!val_name}"
  if [[ "$line" =~ : ]]; then
    yashLogError "syntax error - two keys cannot start at one line"
    return 1
  else
    yash_sanitize_value "${type_name}" "${val_name}" || return 1
  fi
}

yash_sanitize_value() {
  local IFS=$'\n' line buffer type_name="$1" val_name="$2" indent
  {
    while read -r line; do
      [[ "$line" =~ ^[[:space:]]*$ ]] || break
    done
    if [[ "$line" =~ ^[[:space:]]*\|[[:space:]]*$ ]]; then
      yashLogDebug "multiline text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      buffer="${line:$indent}"$'\n'
      while read -e line; do
        buffer+="${line:$indent}"$'\n'
      done
      buffer+=" "
    elif [[ "$line" =~ ^[[:space:]]*\>[[:space:]]*$ ]]; then
      yashLogDebug "wrapped text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer="${line:$indent} "
      while read -e line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+="${line:$indent}"$'\n'
      done
      buffer+=" "
    elif [[ "$line" =~ ^[[:space:]]*- || "$line" =~ ^[^:]*: ]]; then
      yashLogDebug "sub-structure"
      eval "${type_name}=struct"
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer="${line:$indent}"$'\n'
      while read -e line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+="${line:$indent}"$'\n'
      done
    else
      yashLogDebug "simple string"
      eval "${type_name}=text"
      [[ "$line" =~ ^[[:space:]]$ ]] && read -r line
      [[ "$line" =~ ^[[:space:]]*([^[:space:]].*)$ ]]
      line="${BASH_REMATCH[1]}"
      [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
      buffer="${BASH_REMATCH[1]} "
      while read -e line; do
        [[ "$line" =~ ^[[:space:]]*(.*)$ ]]
        line="${BASH_REMATCH[1]}"
        [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
        buffer+="${BASH_REMATCH[1]} "
      done
    fi
  } <<< "${!val_name}"
  eval "$val_name=\"\${buffer::-1}\""
}

yash_parse() {
  local yaml_data item key value data_type item_type item_type_prev prefix="$3" index=0 yaml_name="$1" res=0
  yaml_data="$(yash_clean "$2")"

  yashLogDebug "$yaml_data"
  yashLogDebug "============================="
  yashLogDebug ""

  while yash_get_next item_type item yaml_data; do
    [[ -n "$item_type_prev" ]] && {
      [[ "$item_type_prev" == "$item_type" ]] || { yashLogError "invalid input - different item types in one list"; return 1; }
    }
    item_type_prev="$item_type"
    yash_parse_item data_type key value "$item" || return 1
    [[ "$item_type" == "index" ]] && key=$((index++))
    yashLogDebug "$prefix$key ($data_type):"
    yashLogDebug "$value'"
    yashLogDebug -----------------------------
    [[ "$data_type" != "struct" ]] && {
      [[ -z "$value" ]] && {
        eval "${yaml_name}['$prefix$key']='null'"
      } || {
        eval "${yaml_name}['$prefix$key']=\"\${value}\""
      }
    }
    if [[ "$data_type" == "struct" ]]; then
      yashLogDebug "_____________________________"
      yash_parse "$yaml_name" "$value" "$prefix$key." || return 1
    fi
  done
}
