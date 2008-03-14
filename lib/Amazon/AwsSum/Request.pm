## ----------------------------------------------------------------------------
package Amazon::AwsSum::Request;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(add_parameter add_numeral_parameters add_common_parameters add_signature make_querystring);

use List::Util qw( reduce );
use Digest::HMAC_SHA1;
use URI::Escape;
use DateTime;

## ----------------------------------------------------------------------------

sub add_parameter {
    my ($request, $name, $val) = @_;
    return unless defined $val;

    $request->{$name} = $val;
}

sub add_numeral_parameters {
    my ($request, $name, $val) = @_;

    return unless defined $val;

    # just one to add
    unless ( ref $val ) {
        $request->{"$name.1"} = $val;
        return;
    }

    # should be an array
    my $i = 0;
    foreach ( @$val ) {
        $i++;
        $request->{"$name.$i"} = $_;
    }
}

sub add_common_parameters {
    my ($request, $access_key, $version) = @_;
    $request->{Timestamp} = DateTime->now( time_zone => 'UTC' )->strftime("%Y-%m-%dT%H:%M:%SZ");
    $request->{Version} = $version;
    $request->{AWSAccessKeyId} = $access_key;
    $request->{SignatureVersion} = 1;
}

sub add_signature {
    my ($request, $secret_access_key) = @_;
    $request->{Signature} = compute_base64( $request, $secret_access_key );
}

sub compute_base64 {
    my ($request, $secret_access_key) = @_;

    my @order = sort { lc($a) cmp lc($b) } keys %$request;
    my $data = reduce { $a . $b . $request->{$b} } '', @order;

	my $digest = Digest::HMAC_SHA1->new( $secret_access_key );
	$digest->add( $data );

    return $digest->b64digest . '=';
}

sub make_querystring {
    my ($request) = @_;

    my $query = join('&', map { "$_=" . uri_escape($request->{$_}) } keys %$request);
    return $query;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
