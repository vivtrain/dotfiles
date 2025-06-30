#!/bin/bash
realpath $1 | sed "s:`realpath ~`:~:" | sed -E 's:/([^/]{10})([^/]{1,}):/\1…:g'
  | rev | cut -d'/' -f-3 | rev
