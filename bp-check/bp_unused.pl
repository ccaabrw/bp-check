#!/bin/perl

@images_in_subimage=`ls -1 /nfs/rcs/subimage/newdos|sed 's/[\/\*]//'`;

my %images;

while (`grep -v '^#' ~ccsposg/bp_check/image-servers.txt|cut -f1 -d' '|sort|uniq`) {
	print "jkhkjjh$_";
	chomp;
	$images{$_}++;
}

print %images;

