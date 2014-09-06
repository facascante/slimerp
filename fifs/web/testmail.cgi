#!/usr/bin/perl -w
use Email; 

use strict; 
my $to = 'erwin.macaraig@gmail.com'; 
my $from = 'e.macaraig@sportingpulseinternational.com';
my $sbj = 'This is a test email.';
my $hdr = 'test testtwo testthree';
my $hMsg = '<strong>Hello world</strong>';
my $txtMsg = 'Hello erwin';
my $log_text = 'another test'; 
my $BCC = 'erwin_macaraig@yahoo.com';

sendEmail($to,$from,$sbj,$hdr, $hMsg, $txtMsg, $log_text, $BCC);

print "Check email if successful!";


