#! /bin/bash

lab5='/home/jiajunc/Desktop/eecs470F20/lab5'

#diff writeback.out and program.out, wirte results to writeback.diff.ut and mem.diff.out 
for file in $lab5/gt_output/*.writeback.out; do
    file=$(echo $file | cut -d'/' -f8 | cut -d'.' -f1)
    cd $lab5
 
    diff ./gt_output/$file.writeback.out ./my_output/$file.writeback.out >> writeback.diff.out

    grep "@@@" ./gt_output/$file.program.out > ./gt_grep/$file.mem.out #grep @@@ lines
    grep "@@@" ./my_output/$file.program.out > ./my_grep/$file.mem.out
    diff ./gt_grep/$file.mem.out ./my_grep/$file.mem.out >> mem.diff.out
done

#if writeback.diff.out is empty then test passes
if test -e writeback.diff.out;then
    if test -s writeback.diff.out;then
        echo -e "writeback.diff test\033[31m failed. \033[0m"
    else
        echo -e "writeback.diff test\033[32m passed. \033[0m"
    fi
    rm -f writeback.diff.out
else
    echo "File writeback.diff.out does not exist."
fi

#if mem.diff.out is empty then test passes
if test -e mem.diff.out;then
    if test -s mem.diff.out;then
        echo -e "mem.diff test\033[31m failed. \033[0m"
    else
        echo -e "mem.diff test\033[32m passed. \033[0m"
    fi
    rm -f mem.diff.out
else
    echo "File mem.diff.out does not exist."
fi


