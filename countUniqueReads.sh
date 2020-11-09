#!/bin/bash
if [ -z "$1" ]; then
   grep -v ">"  | sort | uniq -c | cat -n | awk '{printf(">%s%s_count=%s\n%s\n","Sequence",$1,$2,$3)}' - 
else
   grep -v ">"  | sort -T $1 | uniq -c | cat -n | awk '{printf(">%s%s_count=%s\n%s\n","Sequence",$1,$2,$3)}' - 
fi
