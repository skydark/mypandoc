#!/bin/bash

# make.sh infile [format]

help () {
    echo "convert pandoc.md"
    echo "Usage:"
    echo "  $(basename "$0") your_markdown_file [profile]"
    exit 0
}

DEFAULT_PROFILE=beamer
[ "$1" ] || help
IN_FILE="$(realpath "$1")"
BASE_IN_FILE="$(basename "$IN_FILE")"
IN_DIR="$(realpath "$(dirname "$1")")"
shift

CUR_DIR="$(dirname "$(readlink -f "$0")")"
OUT_DIR="$CUR_DIR/output"

cd "$CUR_DIR"

source config.sh
if [ "$1" ] ; then
    PROFILE="$1"
else
    : ${PROFILE:="$DEFAULT_PROFILE"}
fi
OUT_OPTIONS=()
PROFILE_SH="profile/$PROFILE.sh"
if [ -f "$PROFILE_SH" ] ; then
    source "profile/$PROFILE.sh"
else
    echo "ERROR: Profile $PROFILE_SH not found!"
    exit 1
fi

# `: ${A:=hello}` is a shortcut in bash for `A=${A:-hello}`
: ${OUT_FORMAT:='latex'}
: ${CP:='cp'}
: ${OUT_EXT:='.tex'}
: ${OUT_FORMAT_PANDOC:="$OUT_FORMAT"}
: ${OUT_FORMAT_FILTER:="$OUT_FORMAT"}
: ${POST_PROCESS:='true'}
: ${TEMPLATE:="default.$PROFILE"}
: ${OUT_FILE:="output$OUT_EXT"}
: ${POST_OUT_EXT:="$OUT_EXT"}
OUT_FILE="$OUT_DIR/$OUT_FILE"
TEMPLATE="$CUR_DIR/template/$TEMPLATE"
OUT_OPTIONS+=( $@ )
POST_OUT_FILE="${OUT_FILE%.*}$POST_OUT_EXT"
FINAL_OUT_FILE="$IN_DIR/${BASE_IN_FILE%.*}$POST_OUT_EXT"

cd "$OUT_DIR"

cat "$IN_FILE" |\
    sed "s|{{ BASE_PATH }}|${BASE_PATH}|g" |\
    sed "s|{{ BASE_PATH_REMOTE }}|${BASE_PATH_REMOTE}|g" |\
    pandoc -f markdown-yaml_metadata_block -t json |\
    "$CUR_DIR/Filter" "$OUT_FORMAT_FILTER" |\
    pandoc -f json -t "$OUT_FORMAT_PANDOC" --template="$TEMPLATE" -o "$OUT_FILE" "${OUT_OPTIONS[@]}" &&\
    "$POST_PROCESS" "$OUT_FILE" && "$CP" "$POST_OUT_FILE" "$FINAL_OUT_FILE"

# pandoc -f json -t dzslides --template=default.revealjs -o reveal.html -V theme:simple --section-divs --standalone
# pandoc --template=default.beamer -t beamer -o beamer.tex -V cjk=yes "$1"
# pandoc --template=default.revealjs -t dzslides -o reveal.html -V theme:simple --section-divs --standalone "$1"

