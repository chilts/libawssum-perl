#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Config::Simple;
use File::Slurp;

use Amazon::AwsSum::S3;

## ----------------------------------------------------------------------------

my $bucket    = 'gallery.kapiti.geek.nz';

## ----------------------------------------------------------------------------

my $cfg = {};
Config::Simple->import_from( "$ENV{HOME}/.awssum", $cfg );

die "couldn't find access key and/or secret key"
    unless ( defined $cfg->{AwsAccessKeyId} and defined $cfg->{AwsSecretAccessKey} );

my $s3 = Amazon::AwsSum::S3->new();
$s3->access_key_id( $cfg->{AwsAccessKeyId} );
$s3->secret_access_key( $cfg->{AwsSecretAccessKey} );

print "Report bucket contents...\n\n";

$s3->ListKeys({
    Bucket => $bucket,
});

my $data = $s3->data;

foreach my $obj ( @{$data->{Contents}} ) {
    print "$obj->{LastModified}   $obj->{ETag}   $obj->{Key} ($obj->{Size})\n";
}

print "\n...done\n";

## ----------------------------------------------------------------------------
