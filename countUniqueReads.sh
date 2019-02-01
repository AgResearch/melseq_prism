#!/bin/bash
grep -v ">"  | sort | uniq -c | cat -n | awk '{printf(">%s%s_count=%s\n%s\n","Sequence",$1,$2,$3)}' - 
