#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Config::Simple;
use File::Slurp;
use Image::Imlib2;

use Amazon::AwsSum::S3;
use Amazon::AwsSum::SQS;

## ----------------------------------------------------------------------------

my $bucket      = 'gallery.kapiti.geek.nz';
my $queue_url   = 'https://queue.amazonaws.com/images';
my $domain_name = 'Images';

my $sizes = {
    t => 100,
    s => 200,
    m => 400,
    l => 800,
};

## ----------------------------------------------------------------------------

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

while (1) {
    print "Retrieving messages from the queue...\n";

    # use Data::Dumper;
    # print Dumper($sqs);

    # see if there are any messages in the queue
    $sqs->ReceiveMessage({
        QueueUrl => $queue_url,
    });

    my $data = $sqs->data();

    # see if there is a message
    if ( defined $data->{ReceiveMessageResult}{Message} ) {
        my $message = $data->{ReceiveMessageResult}{Message};
        # process this message
        process_image( $message->{Body} );

        # set as done
        $sqs->DeleteMessage({
            QueueUrl      => $queue_url,
            ReceiptHandle => $message->{ReceiptHandle},
        });
    }
    else {
        print "...no messages at the present time\n";
    }

    print "...done that iteration\n\n";

    # random sleep, but you probably want a gradual back-off strategy
    sleep int(rand(5)) + 5;
}

## ----------------------------------------------------------------------------

sub process_image {
    my ($filename) = @_;

    print "...getting '$filename'\n";

    # firstly, get this image from S3
    $s3->GetObject({
        Bucket => $bucket,
        Key    => $filename,
    });

    # write a temporary file
    write_file( "$filename.tmp", $s3->http_response->content );
    my $image = Image::Imlib2->load("$filename.tmp");

    # generate the t, s, m and l
    foreach my $size ( keys %$sizes ) {
        print "...generating '$size' ($sizes->{$size}) size\n";
        my $scaled_image;
        if ( $image->get_width > $image->get_height ) {
            $scaled_image = $image->create_scaled_image($sizes->{$size}, 0);
        }
        else {
            $scaled_image = $image->create_scaled_image(0, $sizes->{$size});
        }
        print "...generated (" . $scaled_image->get_width . ", " . $scaled_image->get_height . ")\n";

        my $new_filename = "${size}_$filename";

        # convert to jpg and save
        $scaled_image->image_set_format("jpeg");
        $scaled_image->save( $new_filename);

        print "...putting '$new_filename'\n";

        # now put it into S3
        my $content = read_file( $new_filename );
        $s3->PutObject(
            {
                Bucket  => $bucket,
                Key     => $new_filename,
                Acl     => 'public-read',
                headers => { 'Content-Type' => 'image/jpg' },
                content => $content,
            }
        );
    }

    unlink "$filename.tmp";
}

## ----------------------------------------------------------------------------
