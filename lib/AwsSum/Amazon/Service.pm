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
# helper functions specifically for Amazon services (not necessarily all of them)

# useful for EC2 and SimpleDB (and maybe others)
sub _amazon_add_flattened_array_to_params {
    my ($self, $name, $array) = @_;

    # count which key we're up to (start at 1)
    my $i = 1;

    # loop through everything, keep a number and save each key
    foreach my $item ( @$array ) {
        foreach my $key ( keys %$item ) {
            $self->set_param( "$name.$i.$key", $item->{$key} );
        }
        $i++;
    }
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
