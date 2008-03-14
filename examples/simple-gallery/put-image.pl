#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Config::Simple;
use File::Slurp;
use Image::EXIF;

use Amazon::AwsSum::S3;
use Amazon::AwsSum::SQS;

## ----------------------------------------------------------------------------

my $bucket    = 'gallery.kapiti.geek.nz';
my $queue_url = 'https://queue.amazonaws.com/images';
my $domain    = 'Images';

## ----------------------------------------------------------------------------

my ($filename) = @ARGV;

die 'provide a image file to put'
    unless defined $filename;

die 'file does not exist'
    unless -f $filename;

my $cfg = {};
Config::Simple->import_from( "$ENV{HOME}/.awssum", $cfg );

die "couldn't find access key and/or secret key"
    unless ( defined $cfg->{AwsAccessKeyId} and defined $cfg->{AwsSecretAccessKey} );

my $s3 = Amazon::AwsSum::S3->new();
my $sqs = Amazon::AwsSum::SQS->new();

foreach ( $s3, $sqs ) {
    $_->access_key_id( $cfg->{AwsAccessKeyId} );
    $_->secret_access_key( $cfg->{AwsSecretAccessKey} );
}

print "Adding '$filename' to the bucket...\n";

# read the file in (presume it's a jpg)
my $content = read_file( $filename );
$s3->PutObject(
    {
        Bucket  => $bucket,
        Key     => $filename,
        headers => { 'Content-Type' => 'image/jpg' },
        content => $content,
    }
);

print "Adding '$filename' to the queue...\n";

# add the filename to the queue
$sqs->SendMessage({
    QueueUrl    => $queue_url,
    MessageBody => $filename,
});

print "...done\n";

## ----------------------------------------------------------------------------
