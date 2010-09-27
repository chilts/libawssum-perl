## ----------------------------------------------------------------------------

package AwsSum::Amazon::Service;
use Moose::Role;
use Moose::Util::TypeConstraints;

# some things required from the user
has 'access_key_id'    => ( is => 'rw', isa => 'Str' );
has 'secret_access_key' => ( is => 'rw', isa => 'Str' );

my $allowed = {
    region => {
        'us-east-1'      => 1,
        'us-west-1'      => 1,
        'eu-west-1'      => 1,
        'ap-southeast-1' => 1,
    },
};

# setup the all of the endpoints in AWS
enum 'Endpoint' => qw(us-east-1 us-west-1 eu-west-1 ap-southeast-1);
has 'endpoint' => ( is => 'rw', isa => 'Endpoint', default => 'us-east-1' );

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
