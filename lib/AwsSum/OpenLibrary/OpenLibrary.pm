## ----------------------------------------------------------------------------

package AwsSum::OpenLibrary::OpenLibrary;

use Moose;
with 'AwsSum::Service';

use Carp;
use JSON::Any;

## ----------------------------------------------------------------------------
# we require these things off the using code

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

has '_this_path' => ( is => 'rw', isa => 'Str' );

## ----------------------------------------------------------------------------

my $commands = {
    Author => {
        name           => 'Author',
        method         => 'author',
    },
    Book => {
        name           => 'Book',
        method         => 'book',
    },
    RecentChanges => {
        name           => 'RecentChanges',
        method         => 'recent_changes',
    },
    Books => {
        name           => 'Books',
        method         => 'books',
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }

sub verb { 'get' }

sub url {
    my ($self) = @_;

    my $url = q{http://openlibrary.org/};
    $url .= $self->_this_path;

    return $url;
}

sub code { 200 }

sub sign {}

sub decode {
    my ($self) = @_;

    $self->data( JSON::Any->jsonToObj( $self->res->content() ) );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub author {
    my ($self, $param) = @_;

    $self->set_command( 'Author' );
    unless ( defined $param->{AuthorName} ) {
        croak "Provide an 'AuthorName' to query";
    }
    $self->_this_path( 'authors/' . $param->{AuthorName} . '.json' );

    return $self->send();
}

sub book {
    my ($self, $param) = @_;

    $self->set_command( 'Book' );
    unless ( defined $param->{BookName} ) {
        croak "Provide a 'BookName' to query";
    }
    $self->_this_path( 'books/' . $param->{BookName} . '.json' );

    return $self->send();
}

sub recent_changes {
    my ($self, $param) = @_;

    $self->set_command( 'RecentChanges' );
    $self->_this_path( 'recentchanges.json' );

    return $self->send();
}

sub books {
    my ($self, $param) = @_;

    $self->set_command( 'Books' );
    $self->set_param( 'format', 'json' );
    foreach my $param_name ( qw(bibkeys format callback jscmd) ) {
        $self->set_param( $param_name, $param->{$param_name} )
            if $param->{$param_name};
    }
    $self->_this_path( 'api/books' );

    return $self->send();
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------
