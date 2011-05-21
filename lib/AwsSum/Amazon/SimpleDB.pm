## ----------------------------------------------------------------------------

package AwsSum::Amazon::SimpleDB;

use Moose;
use Moose::Util::TypeConstraints;
with qw(
    AwsSum::Service
    AwsSum::Amazon::Service
);
use Data::Dump qw(pp);
use Carp;
use DateTime;
use List::Util qw( reduce );
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64);
use XML::Simple;
use URI::Escape;
use MIME::Base64;

## ----------------------------------------------------------------------------
# setup details needed or pre-determined

# some things required from the user
enum 'SignatureMethod' => qw(HmacSHA1 HmacSHA256);
has 'signature_method'   => ( is => 'rw', isa => 'SignatureMethod', default => 'HmacSHA256' );

# constants
# From: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/DocumentHistory.html
sub version { '2009-04-15' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # In order of: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/SDB_API_Operations.html

    BatchDeleteAttributes => {
        name   => 'BatchDeleteAttributes',
        method => 'batch_delete_attributes',
    },
    BatchPutAttributes => {
        name   => 'BatchPutAttributes',
        method => 'batch_put_attributes',
    },
    CreateDomain => {
        name   => 'CreateDomain',
        method => 'create_domain',
    },
    DeleteAttributes => {
        name   => 'DeleteAttributes',
        method => 'delete_attributes',
    },
    DeleteDomain => {
        name   => 'DeleteDomain',
        method => 'delete_domain',
    },
    DomainMetadata => {
        name   => 'DomainMetadata',
        method => 'domain_metadata',
    },
    GetAttributes => {
        name   => 'GetAttributes',
        method => 'get_attributes',
    },
    ListDomains => {
        name   => 'ListDomains',
        method => 'list_domains',
    },
    PutAttributes => {
        name   => 'PutAttributes',
        method => 'put_attributes',
    },
    Select => {
        name   => 'Select',
        method => 'select',
    },
};

sub _host {
    my ($self) = @_;
    return $self->region eq 'us-east-1'
        ? q{sdb.amazonaws.com}
        : q{sdb.} . $self->region . q{.amazonaws.com}
    ;
}

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

# * commands
# * verb
# * url
# * code
# * sign
# * decode

sub commands { $commands }

sub cmd_attr {
    my ($self, $attr) = @_;
    return $self->_command->{$attr};
}

sub verb { 'get' }

sub url {
    my ($self) = @_;
    return q{https://} . $self->_host . q{/};
}

sub code { 200 }

sub sign {
    my ($self) = @_;

    my $date = DateTime->now( time_zone => 'UTC' )->strftime("%Y-%m-%dT%H:%M:%SZ");

    # add the service params first before signing
    $self->set_param( 'Action', $self->_command->{name} );
    $self->set_param( 'Version', $self->version );
    $self->set_param( 'AWSAccessKeyId', $self->access_key_id );
    $self->set_param( 'Timestamp', $date );
    $self->set_param( 'SignatureVersion', 2 );
    $self->set_param( 'SignatureMethod', $self->signature_method );

    # See: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/HMACAuth.html

    # sign the request (remember this is SignatureVersion '2')
    my $str_to_sign = '';
    $str_to_sign .= uc($self->verb) . "\n";
    $str_to_sign .= $self->_host . "\n";
    $str_to_sign .= "/\n";

    # do the params ourselves, since it seems quite fussy regarding various chars
    my $param = $self->params();
    $str_to_sign .= join('&', map { "$_=" . uri_escape($param->{$_}, q{^A-Za-z0-9_.~-} ) } sort keys %$param);

    # sign the $str_to_sign
    my $signature = ( $self->signature_method eq 'HmacSHA1' )
        ? hmac_sha1_base64($str_to_sign, $self->secret_access_key )
        : hmac_sha256_base64($str_to_sign, $self->secret_access_key );
    $self->set_param( 'Signature', $signature . '=' );
}

sub decode {
    my ($self) = @_;

    # With SimpleDB, we _always_ get some XML back no matter what happened.
    # Note: KeyAttr => [] is to stop folding into a hash
    my $data = XMLin( $self->res->content(), KeyAttr => [] );

    # see if this request passed the expected return code (this is the only
    # check we do here)
    if ( $self->res_code == $self->code ) {
        $data->{_awssum} = {
            'ok' => 1,
        }
    }
    else {
        $data->{_awssum} = {
            'ok'      => 0,
            'error'   => $data->{Errors}{Error}{Code},
            'message' => $data->{Errors}{Error}{Message},
        }
    }

    # save it for the outside world
    $self->data( $data );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub batch_delete_attributes {
    my ($self, $param) = @_;
    $self->clear();

    # ok, this is going to be interesing

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to query";
    }

    unless ( defined $param->{Items} and ref $param->{Items} eq 'ARRAY' ) {
        croak "Provide an array of 'Items' to save";
    }

    # all ok, now fill in the params
    $self->set_command( 'BatchDeleteAttributes' );
    $self->set_param( qw(DomainName), $param->{DomainName} );

    # now loop through all the items
    my $item_num = 0;
    foreach my $item ( @{$param->{Items}} ) {
        # set this item name
        $self->set_param( qq{Item.$item_num.ItemName}, $item->{Name} );

        # now do the adds
        my $count = 0;
        foreach my $key ( keys %{$item->{Attribute}} ) {
            if ( ref $item->{Attribute}{$key} eq 'ARRAY' ) {
                foreach my $value ( @{$item->{Attribute}{$key}} ) {
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $value );
                    $count++;
                }
            }
            else {
                # just one value
                $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $item->{Attribute}{$key} );
                $count++;
            }
        }

        # increment the item number
        $item_num++;
    }

    return $self->send();
}

sub batch_put_attributes {
    my ($self, $param) = @_;
    $self->clear();

    # ok, this is going to be interesing

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to query";
    }

    unless ( defined $param->{Items} and ref $param->{Items} eq 'ARRAY' ) {
        croak "Provide an array of 'Items' to save";
    }

    # all ok, now fill in the params
    $self->set_command( 'BatchPutAttributes' );
    $self->set_param( qw(DomainName), $param->{DomainName} );

    # now loop through all the items
    my $item_num = 0;
    foreach my $item ( @{$param->{Items}} ) {
        # set this item name
        $self->set_param( qq{Item.$item_num.ItemName}, $item->{Name} );

        # now do the adds
        my $count = 0;
        foreach my $key ( keys %{$item->{Add}} ) {
            if ( ref $item->{Add}{$key} eq 'ARRAY' ) {
                foreach my $value ( @{$item->{Add}{$key}} ) {
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $value );
                    $count++;
                }
            }
            else {
                # just one value
                $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $item->{Add}{$key} );
                $count++;
            }
        }

        # do all the replaces
        foreach my $key ( keys %{$item->{Replace}} ) {
            if ( ref $item->{Replace}{$key} eq 'ARRAY' ) {
                foreach my $value ( @{$item->{Replace}{$key}} ) {
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $value );
                    $self->set_param( qq{Item.$item_num.Attribute.$count.Replace}, 'true' );
                    $count++;
                }
            }
            else {
                # just one value
                $self->set_param( qq{Item.$item_num.Attribute.$count.Name}, $key );
                $self->set_param( qq{Item.$item_num.Attribute.$count.Value}, $item->{Replace}{$key} );
                $self->set_param( qq{Item.$item_num.Attribute.$count.Replace}, 'true' );
                $count++;
            }
        }
        $item_num++;
    }

    return $self->send();
}

sub create_domain {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to create";
    }

    $self->set_command( 'CreateDomain' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName)
    );

    return $self->send();
}

sub delete_attributes {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName'";
    }

    # check we have an item
    unless ( defined $param->{ItemName} ) {
        croak "Provide a 'ItemName' to delete attributes from";
    }

    $param->{Delete} ||= {};

    unless ( ref $param->{Delete} eq 'HASH' ) {
        croak "'Delete' should be a hash";
    }
    if ( defined $param->{Expected} ) {
        unless ( ref $param->{Expected} eq 'HASH' ) {
            croak "'Exists' should be a hash";
        }

        # make sure we have a name and a value
        unless ( defined $param->{Expected}{Name} ) {
            croak "'Expected' must contain a 'Name'";
        }
        unless ( defined $param->{Expected}{Value} ) {
            croak "'Expected' must contain a 'Value'";
        }
    }
    if ( defined $param->{NotExists} ) {
        # should be a scalar value
        if ( ref $param->{NotExists} ) {
            croak "'NotExists' should be a scalar value (a 'Name')";
        }
    }
    if ( defined $param->{Expected} and defined $param->{NotExists} ) {
        croak "You may only either 'Expected' or 'NotExists'";
    }

    # all ok, now fill in the params
    $self->set_command( 'DeleteAttributes' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName ItemName)
    );

    # do all the deletes
    my $count = 0;
    foreach my $key ( keys %{$param->{Delete}} ) {
        if ( ref $param->{Delete}{$key} eq 'ARRAY' ) {
            foreach my $value ( @{$param->{Delete}{$key}} ) {
                $self->set_param( qq{Attribute.$count.Name}, $key );
                $self->set_param( qq{Attribute.$count.Value}, $value );
                $count++;
            }
        }
        else {
            # just one value
            $self->set_param( qq{Attribute.$count.Name}, $key );
            $self->set_param( qq{Attribute.$count.Value}, $param->{Delete}{$key} );
            $count++;
        }
    }

    # do the expected value
    if ( $param->{Expected} ) {
        $self->set_param( qq{Expected.$count.Name}, $param->{Expected}{Name} );
        $self->set_param( qq{Expected.$count.Value}, $param->{Expected}{Value} );
        $self->set_param( qq{Expected.$count.Exists}, 'true' );
        $count++;
    }

    # do all the not exists
    if ( defined $param->{NotExists} ) {
        $self->set_param( qq{Expected.$count.Name}, $param->{NotExists} );
        $self->set_param( qq{Expected.$count.Exists}, 'false' );
        $count++;
    }

    return $self->send();
}

sub delete_domain {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to delete";
    }

    $self->set_command( 'DeleteDomain' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName)
    );

    my $data = $self->send();
    return $data;
}

sub domain_metadata {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to query";
    }

    $self->set_command( 'DomainMetadata' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName)
    );

    my $data = $self->send();
    if ( exists $data->{DomainMetadataResult} ) {
        $data->{DomainMetadata} = delete $data->{DomainMetadataResult};
    }
    return $data;
}

sub get_attributes {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to query";
    }

    # check we have an item
    unless ( defined $param->{ItemName} ) {
        croak "Provide a 'ItemName' to query";
    }

    $self->set_command( 'GetAttributes' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName ItemName AttributeName ConsistentRead)
    );

    my $data = $self->send();
    if ( exists $data->{GetAttributesResult}{Attribute} ) {
        my $attr = {};
        foreach my $pair ( @{$data->{GetAttributesResult}{Attribute}} ) {
            # either push onto the array, make a new array or just set the value
            if ( ref $attr->{$pair->{Name}} eq 'ARRAY' ) {
                push @{$attr->{$pair->{Name}}}, $pair->{Value};
            }
            elsif ( exists $attr->{$pair->{Name}} ) {
                $attr->{$pair->{Name}} = [ $attr->{$pair->{Name}} ];
                push @{$attr->{$pair->{Name}}}, $pair->{Value};
            }
            else {
                $attr->{$pair->{Name}} = $pair->{Value};
            }
        }

        $data->{Item}{Attribute} = $attr;
        $data->{Item}{Name} = $param->{ItemName};
    }
    else {
        $data->{Item} = undef;
    }
    delete $data->{GetAttributesResult};

    return $data;
}

sub list_domains {
    my ($self, $param) = @_;
    $self->clear();

    $self->set_command( 'ListDomains' );
    $self->set_params_if_defined(
        $param,
        qw(MaxNumberOfDomains NextToken)
    );

    # get the data
    my $data = $self->send();

    # do some munging and return
    if ( exists $data->{ListDomainsResult} ) {
        $self->_force_array( $data->{ListDomainsResult}{DomainName} );
        $data->{DomainNames} = delete $data->{ListDomainsResult}{DomainName};
        delete $data->{ListDomainsResult};
    }
    return $data;
}

sub put_attributes {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{DomainName} ) {
        croak "Provide a 'DomainName' to query";
    }

    # check we have an item
    unless ( defined $param->{ItemName} ) {
        croak "Provide a 'ItemName' to query";
    }

    # now, we're going to have a 'Put' or a 'Replace' hash
    unless ( defined $param->{Add} or defined $param->{Replace} ) {
        croak "Provide either a 'Add' or 'Replace' hash";
    }

    $param->{Add} ||= {};
    $param->{Replace} ||= {};

    unless ( ref $param->{Add} eq 'HASH' ) {
        croak "'Add' should be a hash";
    }
    unless ( ref $param->{Replace} eq 'HASH' ) {
        croak "'Replace' should be a hash";
    }
    if ( defined $param->{Expected} ) {
        unless ( ref $param->{Expected} eq 'HASH' ) {
            croak "'Exists' should be a hash";
        }

        # make sure we have a name and a value
        unless ( defined $param->{Expected}{Name} ) {
            croak "'Expected' must contain a 'Name'";
        }
        unless ( defined $param->{Expected}{Value} ) {
            croak "'Expected' must contain a 'Value'";
        }
    }
    if ( defined $param->{NotExists} ) {
        # should be a scalar value
        if ( ref $param->{NotExists} ) {
            croak "'NotExists' should be a scalar value (a 'Name')";
        }
    }

    if ( defined $param->{Expected} and defined $param->{NotExists} ) {
        croak "You may only either 'Expected' or 'NotExists'";
    }

    # all ok, now fill in the params
    $self->set_command( 'PutAttributes' );
    $self->set_params_if_defined(
        $param,
        qw(DomainName ItemName)
    );

    # do all the puts
    my $count = 0;
    foreach my $key ( keys %{$param->{Add}} ) {
        if ( ref $param->{Add}{$key} eq 'ARRAY' ) {
            foreach my $value ( @{$param->{Add}{$key}} ) {
                $self->set_param( qq{Attribute.$count.Name}, $key );
                $self->set_param( qq{Attribute.$count.Value}, $value );
                $count++;
            }
        }
        else {
            # just one value
            $self->set_param( qq{Attribute.$count.Name}, $key );
            $self->set_param( qq{Attribute.$count.Value}, $param->{Add}{$key} );
            $count++;
        }
    }

    # do all the replaces
    foreach my $key ( keys %{$param->{Replace}} ) {
        if ( ref $param->{Replace}{$key} eq 'ARRAY' ) {
            foreach my $value ( @{$param->{Replace}{$key}} ) {
                $self->set_param( qq{Attribute.$count.Name}, $key );
                $self->set_param( qq{Attribute.$count.Value}, $value );
                $self->set_param( qq{Attribute.$count.Replace}, 'true' );
                $count++;
            }
        }
        else {
            # just one value
            $self->set_param( qq{Attribute.$count.Name}, $key );
            $self->set_param( qq{Attribute.$count.Value}, $param->{Replace}{$key} );
            $self->set_param( qq{Attribute.$count.Replace}, 'true' );
            $count++;
        }
    }

    # do the expected value
    if ( $param->{Expected} ) {
        $self->set_param( qq{Expected.$count.Name}, $param->{Expected}{Name} );
        $self->set_param( qq{Expected.$count.Value}, $param->{Expected}{Value} );
        $self->set_param( qq{Expected.$count.Exists}, 'true' );
        $count++;
    }

    # do all the not exists
    if ( defined $param->{NotExists} ) {
        $self->set_param( qq{Expected.$count.Name}, $param->{NotExists} );
        $self->set_param( qq{Expected.$count.Exists}, 'false' );
        $count++;
    }

    return $self->send();
}

sub select {
    my ($self, $param) = @_;
    $self->clear();

    # check we have a domain
    unless ( defined $param->{SelectExpression} ) {
        croak "Provide a 'SelectExpression' to query";
    }

    $self->set_command( 'Select' );
    $self->set_params_if_defined(
        $param,
        qw(SelectExpression ConsistenRead NextToken)
    );

    my $data = $self->send();

    # do some munging
    if ( exists $data->{SelectResult} ) {
        if ( exists $data->{SelectResult}{Item} ) {
            $data->{Result} = delete $data->{SelectResult};
            $self->_force_array( $data->{Result}{Item} );
            $data->{Result}{Items} = delete $data->{Result}{Item};

            # munge each item
            foreach my $item ( @{$data->{Result}{Items}} ) {
                my $attr = {};
                foreach my $pair ( @{$item->{Attribute}} ) {
                    # either push onto the array, make a new array or just set the value
                    if ( ref $attr->{$pair->{Name}} eq 'ARRAY' ) {
                        push @{$attr->{$pair->{Name}}}, $pair->{Value};
                    }
                    elsif ( exists $attr->{$pair->{Name}} ) {
                        $attr->{$pair->{Name}} = [ $attr->{$pair->{Name}} ];
                        push @{$attr->{$pair->{Name}}}, $pair->{Value};
                    }
                    else {
                        $attr->{$pair->{Name}} = $pair->{Value};
                    }
                }

                # set this new hash, rather than an array
                $item->{Attribute} = $attr;
            }
        }
        else {
            $data->{Result} = undef;
            delete $data->{SelectResult};
        }
    }

    return $data;
}

## ----------------------------------------------------------------------------
# internal methods

sub _force_array {
    my $self = shift;
    $_[0] = $self->_make_array_from( $_[0] );
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------

=pod

=head1 NAME

AwsSum::Amazon::SimpleDB - interface to Amazon's SimpleDB web service

=head1 SYNOPSIS

    $sdb = AwsSum::Amazon::SimpleDB->new();
    $sdb->access_key_id( 'abc' );
    $sdb->secret_access_key( 'xyz' );

=cut
