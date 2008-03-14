#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;
use Config::Simple;
use File::Slurp;

use Amazon::AwsSum::S3;
use Amazon::AwsSum::SimpleDB;

## ----------------------------------------------------------------------------

my $bucket = 'gallery.kapiti.geek.nz';

## ----------------------------------------------------------------------------

my $cfg = {};
Config::Simple->import_from( "$ENV{HOME}/.awssum", $cfg );

die "couldn't find access key and/or secret key"
    unless ( defined $cfg->{AwsAccessKeyId} and defined $cfg->{AwsSecretAccessKey} );

my $s3 = Amazon::AwsSum::S3->new();

$s3->access_key_id( $cfg->{AwsAccessKeyId} );
$s3->secret_access_key( $cfg->{AwsSecretAccessKey} );

print "Generating the index page...\n\n";

my $page = <<'EOF';
<html>
    <head><title>Simple Gallery</title></head>
    <body>
    <h1>Simple Gallery</h1>
    <p>Using just S3 and SQS (but using SimpleDB would make it even more oarsum).</p>
EOF

# find all the items in the SimpleDB
$s3->ListKeys({
    Bucket => $bucket,
});

my $data = $s3->data;

foreach my $obj ( @{$data->{Contents}} ) {
    next if $obj->{Key} eq 'index.html';
    next if $obj->{Key} =~ m{ \A [tsml]_ }xms;

    print "...making HTML for '$obj->{Key}'\n";

    $page .= <<"EOF";
<p style="text-align: center;">
    <a href="l_$obj->{Key}"><img src="t_$obj->{Key}"></a>
    <br />
    [ <a href="s_$obj->{Key}">Small</a> | <a href="m_$obj->{Key}">Medium</a> | <a href="l_$obj->{Key}">Large</a> ]
</p>
EOF
}

$page .= <<'EOF';
    </body>
</html>
EOF

# put it into S3 with Acl as public-read so everyone can read it
$s3->PutObject(
    {
        Bucket  => $bucket,
        Key     => 'index.html',
        Acl     => 'public-read',
        headers => { 'Content-Type' => 'text/html' },
        content => $page,
    }
);

print "\n...done\n";

## ----------------------------------------------------------------------------
