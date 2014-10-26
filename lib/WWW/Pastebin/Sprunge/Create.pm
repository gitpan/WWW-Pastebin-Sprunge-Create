use strict;
use warnings;
package WWW::Pastebin::Sprunge::Create;
BEGIN {
  $WWW::Pastebin::Sprunge::Create::VERSION = '0.001';
}
# ABSTRACT: create new pastes on sprunge.us

use Carp;
use URI;
use LWP::UserAgent;
use HTTP::Request::Common;
use File::Slurp qw(read_file);
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    ua
    paste_uri
    error
);

use overload q|""| => sub { shift->paste_uri; };


sub new {
    my $class = shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;
    $args{ua} ||= LWP::UserAgent->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.10) '
                    . 'Gecko/20100915 Ubuntu/10.04 (lucid) Firefox/3.6.10',
    );

    my $self = bless {}, $class;
    $self->ua( $args{ua} );

    return $self;
}


sub paste {
    my ( $self, $text ) = splice @_, 0, 2;

    $self->$_(undef) for qw(paste_uri error);

    defined $text or carp "Undefined paste content" and return;

    croak "Must have even number of optional arguments to paste()"
        if @_ & 1;

    my %args = @_;
    %args = (
        sprunge     => $text,

        %args,
    );

    $args{'lang'} = lc $args{'lang'};

    $args{'file'}
        and not -e $args{'sprunge'}
        and return $self->_set_error("File $args{'sprunge'} does not seem to exist");

    my $ua = $self->ua;
    $ua->requests_redirectable( [ ] );
    my @post_request = $self->_make_request_args( \%args );
    # use Data::Dumper;
    # print Dumper \@post_request and die;
    my $response = $self->ua->request( POST @post_request );
    # print Dumper $response and die;
    if ( $response->is_success() ) {
        my $uri = URI->new($response->{'_content'});
        return $self->_set_error(q{Request was successful but I don't see a link to the paste }
                . $response->code
                . $response->content
        ) unless $uri;
        $uri->query($args{'lang'}) if $args{'lang'};
        return $self->paste_uri($uri);
    }
    else {
        return $self->_set_error($response, 'net');
    }
}

sub _make_request_args {
    my $self = shift;
    my $args = shift;

    if ($args->{'file'}) {
        $args->{'sprunge'} = read_file($args->{'sprunge'});
    }

    return (
        'http://sprunge.us',
        Content_Type => 'form-data',
        Content => [ %{ $args } ],
    );
}


sub _set_error {
    my ( $self, $error, $type ) = @_;

    if ( defined $type and $type eq 'net' ) {
        $self->error( 'Network error: ' . $error->status_line );
    }
    else {
        $self->error( $error );
    }
    return;
}


1;



=pod

=head1 NAME

WWW::Pastebin::Sprunge::Create - create new pastes on sprunge.us

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use strict;
    use warnings;
    use WWW::Pastebin::Sprunge::Create;

    my $sprunge = WWW::Pastebin::Sprunge::Create->new;

    $sprunge->paste('large text to paste')
        or die $sprunge->error();

    print "Your paste is located at $sprunge\n";

=head1 DESCRIPTION

The module provides interface to paste large texts or files to
L<http://sprunge.us>

=head1 METHODS

=head2 new

    my $sprunge = WWW::Pastebin::Sprunge::Create->new;

    my $sprunge = WWW::Pastebin::Sprunge::Create->new(
        timeout => 10,
    );

    my $sprunge = WWW::Pastebin::Sprunge::Create->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a new WWW::Pastebin::Sprunge::Create object.
Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 timeout

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for pasting. B<Defaults to:> C<30> seconds.

=head3 ua

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for pasting, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Pastebin::Sprunge::Create>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head2 paste

    my $paste_uri = $sprunge->paste('lots and lots of text')
        or die $sprunge->error;

    $sprunge->paste(
        'paste.txt',
        file    => 1,
        nick    => 'Zoffix',
        desc    => 'paste from file',
        lang    => 'perl',
    ) or die $sprunge->error;

Instructs the object to create a new paste. If an error occured during
pasting will return either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method.
On success returns a L<URI> object pointing to a newly created paste.
The first argument is mandatory and must be either a scalar containing
the text to paste or a filename. The rest of the arguments are optional
and are passed in a key/value fashion. Possible arguments are as follows:

=head3 file

    $sprunge->paste( 'paste.txt', file => 1 );

B<Optional>.
When set to a true valu
filename of the file containing the text to paste. When set to a false
value the object will treat the first argument as a scalar containing
the text to be pasted. B<Defaults to:> C<0>

=head3 nick

    $sprunge->paste( 'some text', nick => 'Zoffix' );

B<Optional>. Takes a scalar as a value which specifies the nick of the
person creating the paste. B<Defaults to:> empty string (no nick)

=head3 desc

    $sprunge->paste( 'some text', desc => 'some l33t codez' );

B<Optional>. Takes a scalar as a value which specifies the description of
the paste. B<Defaults to:> empty string (no description)

=head3 lang

    $sprunge->paste( 'some text', lang => 'perl' );

B<Optional>. Takes a scalar as a value which must be one of predefined
language codes and specifies (computer) language of the paste, in other
words which syntax highlighting to use. Since sprunge.us uses Pygments
for syntax highlighting, available languages are L<http://pygments.org/languages/>.

=head2 error

    my $paste_
        or die $sprunge->error;

If an error occured during the call to C<paste()>
it will return either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method. Takes
no arguments, returns a human parsable error message explaining why
we failed.

=head2 paste_uri

    my $last_paste_uri = $sprunge->paste_uri;

    print "Paste can be found on $sprunge\n";

Must be called after a successfull call to C<paste()>. Takes no arguments,
returns a L<URI> object pointing to a paste created by the last call
to C<paste()>, i.e. the return value of the last C<paste()> call. This
method is overloaded as C<q|""> thus you can simply interpolate your
object in a string to obtain the paste URI.

=head2 ua

    my $old_LWP_UA_obj = $sprunge->ua;

    $sprunge->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object. Takes one
optional argument which must be an L<LWP::UserAgent> object,
and the object you specify will be used in any subsequent calls
to C<paste()>.

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<http://search.cpan.org/dist/WWW-Pastebin-Sprunge-Create/>.

The development version lives at L<http://github.com/doherty/WWW-Pastebin-Sprunge-Create>
and may be cloned from L<git://github.com/doherty/WWW-Pastebin-Sprunge-Create>.
Instead of sending patches, please fork this project using the standard
git and github infrastructure.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<http://github.com/doherty/WWW-Pastebin-Sprunge-Create/issues>.

=head1 AUTHOR

Mike Doherty <doherty@cs.dal.ca>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2010 by Mike Doherty.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut


__END__
