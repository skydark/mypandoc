#!/bin/bash

# Default: latex
OUT_FORMAT='latex'

IN_FILE="`realpath "$1"`"
IN_DIR="$(realpath "$(dirname "$1")")"
shift

CUR_DIR="$(dirname "$(readlink -f "$0")")"
OUT_DIR="$CUR_DIR/output"

cd "$CUR_DIR"

eval "`sed -e '/^#/d;s/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' config.yaml`"

if [ x"$1" != x"" ]; then
    OUT_FORMAT="$1"
    shift
fi

OUT_FORMAT_PANDOC="$OUT_FORMAT"
OUT_FORMAT_FILTER="$OUT_FORMAT"
# `: ${A:=hello}` is a shortcut in bash for `A=${A:-hello}`
if [ x"$OUT_FORMAT" = x"html" ]; then
    : ${OUT_EXT:='.html'}
    : ${POST_PROCESS:='true'}
    # FIXME: ${OUT_OPTIONS:=( ... )} ====> OUT_OPTIONS='( ... )'
    OUT_OPTIONS=( --standalone --mathjax )
elif [ x"$OUT_FORMAT" = x"latex" ]; then
    : ${OUT_EXT:='.tex'}
    : ${POST_PROCESS:='xelatex'}
    OUT_OPTIONS=( -V 'cjk=yes' )
elif [ x"$OUT_FORMAT" = x"beamer" ]; then
    : ${OUT_EXT:='.tex'}
    : ${POST_PROCESS:='xelatex'}
    OUT_FORMAT_FILTER='latex'
    OUT_OPTIONS=( -V 'cjk=yes' )
elif [ x"$OUT_FORMAT" = x"revealjs" ]; then
    : ${OUT_EXT:='.html'}
    : ${POST_PROCESS:='true'}
    OUT_FORMAT_PANDOC="dzslides"
    OUT_OPTIONS=( -V 'theme:simple' --section-divs --standalone --mathjax )
else
    echo "Unknown output format!"
    exit 1
fi

OUT_OPTIONS+=( $@ )
: ${TEMPLATE:="$CUR_DIR/template/default.$OUT_FORMAT"}
: ${OUT_FILE:="$OUT_DIR/output$OUT_EXT"}
LAST_OUT_FILE="$IN_DIR/$(basename "$IN_FILE")$OUT_EXT"

cd "$OUT_DIR"

cat "$IN_FILE" |\
    sed "s|{{ BASE_PATH }}|${BASE_PATH}|g" |\
    sed "s|{{ BASE_PATH_REMOTE }}|${BASE_PATH_REMOTE}|g" |\
    pandoc -f markdown -t json |\
    "$CUR_DIR/Filter" $OUT_FORMAT_FILTER |\
    pandoc -f json -t $OUT_FORMAT_PANDOC --template="$TEMPLATE" -o "$OUT_FILE" "${OUT_OPTIONS[@]}" &&\
    "$POST_PROCESS" "$OUT_FILE" # && cp "$OUT_FILE" "$LAST_OUT_FILE"

# pandoc -f json -t dzslides --template=default.revealjs -o reveal.html -V theme:simple --section-divs --standalone
# pandoc --template=default.beamer -t beamer -o beamer.tex -V cjk=yes "$1"
# pandoc --template=default.revealjs -t dzslides -o reveal.html -V theme:simple --section-divs --standalone "$1"

