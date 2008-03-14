#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Config::Simple;
use File::Slurp;

use Amazon::AwsSum::SQS;

## ----------------------------------------------------------------------------

my $queue_url = 'https://queue.amazonaws.com/images';

## ----------------------------------------------------------------------------

my $cfg = {};
Config::Simple->import_from( "$ENV{HOME}/.awssum", $cfg );

die "couldn't find access key and/or secret key"
    unless ( defined $cfg->{AwsAccessKeyId} and defined $cfg->{AwsSecretAccessKey} );

my $sqs = Amazon::AwsSum::SQS->new();
$sqs->access_key_id( $cfg->{AwsAccessKeyId} );
$sqs->secret_access_key( $cfg->{AwsSecretAccessKey} );

print "Report for image queue...\n";

$sqs->GetQueueAttributes({
    QueueUrl      => $queue_url,
    AttributeName => 'ApproximateNumberOfMessages',
});

my $data = $sqs->data;
print "\nThere are approximately $data->{GetQueueAttributesResult}{Attribute}{Value} message(s) in the queue\n\n";

print "...done\n";

## ----------------------------------------------------------------------------
