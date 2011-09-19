#!/usr/bin/perl

# Upload documents to Google Documents.
# 
# Copyright 2010 Alessandro Ghedini <al3xbio@gmail.com>
# --------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# Alessandro Ghedini wrote this file. As long as you retain this 
# notice you can do whatever you want with this stuff. If we 
# meet some day, and you think this stuff is worth it, you can 
# buy me a beer in return.
# --------------------------------------------------------------

use HTTP::Request::Common;
use LWP::UserAgent;
use JSON -support_by_pp;
use Media::Type::Simple;

use strict;

die "For info type 'perldoc $0'\n" unless $#ARGV > 0;

my (@files, $email, $pwd);

for (my $i = 0; $i < $#ARGV + 1; $i++) {
	push(@files, $ARGV[$i+1]) if ($ARGV[$i] eq "-f");
	$email	= $ARGV[$i+1] if ($ARGV[$i] eq "-e");
	die "For info type 'perldoc $0'\n" if ($ARGV[$i] eq "-h");
}

print("Password: ");
system('stty','-echo') if $^O eq 'linux';
chop($pwd = <STDIN>);
system('stty','echo') if $^O eq 'linux';
print "\n";

my $ua = LWP::UserAgent -> new;
my $url = 'https://www.google.com/accounts/ClientLogin';

my %request = ('accountType', 'HOSTED_OR_GOOGLE',
	       'Email', $email,
	       'Passwd', $pwd,
	       'service', 'writely',
	       'source', 'GoogleDocsUploader-GoogleDocsUploader-00',
	      );

my $response = $ua -> request(POST $url, [%request]) -> as_string;
my $auth = (split /=/, (split /\n/, (split /\n\n/, $response)[1])[2])[1];

my $status = (split / /,(split /\n/, $response)[0])[1];
die("ERROR: Unauthorized.\n") if $status == 403;

$url = "https://docs.google.com/feeds/documents/private/full?alt=json";

$ua -> default_header('Authorization' => "GoogleLogin auth=$auth");

foreach my $file(@files) {

	if (!open(FILE, $file)) {
		print "ERROR: Unable to open '$file' file.\n";
		next;
	}
	
	my $data = join("", <FILE>);
	close FILE;

	my $mime = type_from_ext(($file =~ m/([^.]+)$/)[0]);
	
	$ua -> default_header('Slug' => $file);

	my $request = HTTP::Request -> new(POST => $url);
	$request -> content_type($mime);
	$request -> content($data);

	my $response = $ua -> request($request) -> as_string;

	$status = (split / /,(split /\n/, $response)[0])[1];
	my $body = (split /\n\n/, $response)[1];

	if ($status != 201) {
		print "ERROR: $body";
		next;
	}

	my $json = new JSON;

	my $json_text = $json -> decode($body);

	my $title = $json_text -> {entry} -> {title} -> {'$t'};
	my $link = $json_text -> {entry} -> {link}[0] -> {href};

	print "Document successfully created with title '$title'.\nLink:\n$link\n";

}

__END__

=head1 NAME

GoogleDocsUploader.pl - Uploads documents to Google Documents.

=head1 USAGE

GoogleDocsUploader [OPTIONS]

=head1 OPTIONS

=over
		
=item -e	Specifies the login email (e.g. example@gmail.com).

=item -f	Specifies the file to upload (can be more than one).

=back

=head1 MULTIPLE FILES UPLOAD

You can upload multiple files by setting multiple '-f' options.

=head1 FILE TYPE

Allowed file types (checked with MIME) are:

	CSV	text/csv
	TSV	text/tab-separated-values
	TAB	text/tab-separated-values
	HTML	text/html
	HTM	text/html
	DOC	application/msword
	DOCX	application/vnd.openxmlformats-officedocument.
					wordprocessingml.document
	ODS	application/x-vnd.oasis.opendocument.spreadsheet
	ODT	application/vnd.oasis.opendocument.text
	RTF	application/rtf
	SXW	application/vnd.sun.xml.writer
	TXT	text/plain
	XLS	application/vnd.ms-excel
	XLSX	application/vnd.openxmlformats-officedocument.
						spreadsheetml.sheet
	PDF	application/pdf
	PPT	application/vnd.ms-powerpoint
	PPS	application/vnd.ms-powerpoint

=cut


