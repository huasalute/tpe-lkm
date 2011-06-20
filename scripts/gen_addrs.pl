#!/usr/bin/perl -w
#
# gen_addrs.pl - Generate the addrs.c file for use in the tpe-lkm module
#
# This script was thrown together really fast to make the addrs.c file
# be generated at make time, rather than have it as a template and it mangled
# at make time. It determines which structs and functions it needs to be
# aware of, as well and get the addresses of the nessisary kernel symbols
#

use strict;
use warnings;

my @files = (
	'execve.c',
);

my @funcs;

print qq~/*

DO NOT EDIT THIS FILE!! It has been auto-generated by make

Edit gen_addrs.pl instead.

*/

#include "tpe.h"

extern void hijack_syscall(struct code_store *cs, const unsigned long code, const unsigned long addr);

~;

foreach my $file (@files) {

	open FILE, $file;
	my @file = <FILE>;
	close FILE;

	# print structs

	foreach my $line (@file) {

		if ($line =~ /^struct code_store /) {
			print "extern " . $line;

			my $func = $line;
			chomp $func;
			$func =~ s/.* cs_//;
			$func =~ s/;.*//;

			push @funcs, $func;
		}

	}

	print "\n";

	# print functions

	my $ok = 0;

	foreach my $line (@file) {

		$line =~ s/\) *\{/);/;

		if ($line =~ /^int tpe_/) {
			$ok = 1;
			print "extern ";
		}

		print $line if $ok == 1;

		if ($line =~ /;/) {
			$ok = 0;
		}

	}

	print "\n";

}

print "void hijack_syscalls(void) {\n";

foreach my $func (@funcs) {

	if ($func =~ /compat/) {
		print "#ifndef CONFIG_X86_32\n";
	}

	chomp(my $addr = `./scripts/find_address.sh $func`);

	if ($? != 0) {
		die "find_address gave non-zero exit status for $func";
	}

	print "\thijack_syscall(&cs_$func, (unsigned long)tpe_$func, 0x$addr);\n";

	if ($func =~ /compat/) {
		print "#endif\n";
	}

}

print "\n}\n";

print "void undo_hijack_syscalls(void) {\n";

foreach my $func (@funcs) {

	if ($func =~ /compat/) {
		print "#ifndef CONFIG_X86_32\n";
	}

	print "\tstop_my_code(&cs_$func);\n";

	if ($func =~ /compat/) {
		print "#endif\n";
	}

}

print "\n}\n";

