#!/usr/bin/perl -w
# slack_login_key.pl: fetch API keys from Slack non-SSO login process
# Copyright (C) 2017-2019 Daniel Beer <dlbeer@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# To run:
#
#     ./slack_login_key.pl <workspace> <email>
#
# You will be prompted for a password.

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use URI::Encode qw(uri_encode);
use Term::ReadKey;

my $workspace = shift || die "You must specify a workspace";
my $email = shift || die "You must specify an email address";

print STDERR "Password for $email in $workspace (will not echo): ";
ReadMode 2;
my $password = ReadLine 0;
ReadMode 0;
print STDERR "\n";

# Need cookies for this
my $ua = LWP::UserAgent->new;
$ua->cookie_jar({});

# Fetch login page, extract anti-CSRF crumb
print STDERR "Fetching cookie and anti-CSRF crumb\n";
my $req = HTTP::Request->new(GET => "https://$workspace.slack.com/");
my $resp = $ua->request($req);
die $resp->message unless $resp->code =~ /^2/;

my $crumb;
$crumb = $1 if $resp->decoded_content =~ /name="crumb" value="([^"]*)"/;
die "Can't find crumb in page" unless $crumb;

# Send login post
print STDERR "Logging in\n";
my %post = ("crumb" => $crumb, "email" => $email, "password" => $password,
	    "remember" => "on", "signin" => 1);
my $body = join('&', map { "$_=" . uri_encode($post{$_}) } keys %post);

$req = HTTP::Request->new(POST => "https://$workspace.slack.com/?no_sso=1");
$req->header("Content-Type" => "application/x-www-form-urlencoded");
$req->content($body);
$resp = $ua->request($req);

unless ($resp->code eq 302) {
    if ($resp->decoded_content =~ /(<p class="[^"]*alert[^"]*".*\n)/) {
	my $line = $1;
	$line =~ s/<[^>]*>//g;
	chomp $line;
	$line =~ s/^ *//;
	warn "Alert in page: $line\n";
    }

    die "Unexpected response: wanted 302, but got " . $resp->code
	unless $resp->code eq 302;
}

# Fetch API key
print STDERR "Fetching API key\n";
$req = HTTP::Request->new(GET => "https://$workspace.slack.com/messages");
$resp = $ua->request($req);
die $resp->message unless $resp->code =~ /^2/;

my $api_token;
$api_token = $1 if $resp->decoded_content =~
  /"api_token" *: *["']([^'"]*)["']/;
die "Can't find API token in page" unless $api_token;
print STDERR "Ok!\n\n";

print "slack_token=$api_token\n";
