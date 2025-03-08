#!perl
use v5.20;
use strict;
use open qw(:std :utf8);

use experimental qw(signatures);

package App::ipinfo;

use Carp qw(croak);
use Geo::IPinfo;
use Encode qw(decode);
use String::Sprintf;

our $VERSION = '1.01';

__PACKAGE__->run(@ARGV) unless caller();

=encoding utf8

=head1 NAME

App::ipinfo - a command-line tool for IPinfo.io

=head1 SYNOPSIS

Call it as the program:

	% ipinfo '%c' [ip addresses]

Do it all at once:

	use App::ipinfo;
	App::ipinfo->run( \%options, @ip_addresses );

Control most of it yourself:

	use App::ipinfo;

	my $app = App::ipinfo->new(
		template => '%c',
		token    => ...,
		);

	foreach my $ip ( @ip_addresses ) {
		my $info = $app->get_info($ip);
		next unless defined $info;
		$app->output( $app->format($info) );
		}

=head1 DESCRIPTION

=head2 Formatting

Most of the data provided by IPinfo has an C<sprintf>-style formatting
code, and for everything else you can use C<%j> to get JSON that you can
format with B<jq> for some other tool.

=over 4

=item * C<%a> - the ASN of the organization

=item * C<%c> - the city of the organization

=item * C<%C> - the country code of the organization

=item * C<%f> - the emoji flag of the country

=item * C<%h> - the hostname for the IP address

=item * C<%i> - the IP address

=item * C<%j> - all the data as JSON

=item * C<%k> - the continent of the organization

=item * C<%L> - the latitude of the organization

=item * C<%l> - the longitude of the organization

=item * C<%n> - the country name of the organization

=item * C<%N> - newline

=item * C<%o> - the organization name

=item * C<%r> - the region of the organization  (i.e. state or province)

=item * C<%t> - the timezone of the organization  (e.g. C<America/New_York> )

=item * C<%T> - tab

=item * C<%%> - literal percent

=back

=head2 Class methods

=over 4

=item * new( HASH )


Allowed keys:

=over 4

=item * error_fh

The filehandle to send error output to. The default is standard error.

=item * template

The template.

=item * output_fh

The filehandle to send error output to. The default is standard output.

=item * token

The API token from IPinfo.io.

=back

=cut

sub new ($class, %hash) {
	state $defaults = {
		output_fh => $class->default_output_fh,
		error_fh  => $class->default_error_fh,
		template  => $class->default_template,
		token     => $class->get_token,
		};

	my %args = ( $defaults->%*, %hash );

	bless \%args, $class;
	}

=item * looks_like_template(STRING)

Returns true if STRING looks like a template. That is, it has a C<%s>.

=cut

sub looks_like_template ($either, $string) {
	-1 < index $string, '%'
	}

=item * CLASS->run( [TEMPLATE,] IP_ADDRESS [, IP_ADDRESS ... ] )

=item * OBJ->run( [TEMPLATE,] IP_ADDRESS [, IP_ADDRESS ... ] )

Format every IP address according to TEMPLATE and send the result to
the output filehandle.

If the first argument looks like a template (has a C<%>), it is used
to format the output. Otherwise, the first argument is taken as the start
of the list of IP addresses and the default format is used.

If the invocant is not a reference, it's used as the class name to
build the object. If the invocant is a reference, it's used as the
object. These are the same and use all the default settings:

	my $obj = App::ipinfo->new;
	$obj->run( @ip_addresses );

	App::ipfinfo->run( @ip_addresses );

=cut
use Mojo::Util qw(dumper);

sub run ($either, @args) {
	my $opts = ref $args[0] eq ref {} ? shift @args : {};
	my $app = ref $either ? $either : $either->new($opts->%*);

	ARG: foreach my $ip (@args) {
		my $info = $app->get_info($ip);
		next ARG unless defined $info;
		$app->output( $app->format( $info ) );
		}
	}

=back

=head2 Instance methods

=over 4

=item * decode_info

Fixup some issues in the API response.

=cut

sub decode_info ($app, $info) {
	my @queue = $info;

	ITEM: while( my $i = shift @queue ) {
		KEY: foreach my $key ( keys $i->%* ) {
			if( ref $i->{$key} eq ref {} ) {
				push @queue, $i->{$key};
				next KEY;
				}
			$i->{$key} = decode( 'UTF-8', $i->{$key} );
			}
		}
	};

=item * default_error_fh

Returns the default for the error filehandle. In this module, it's
standard error.

=cut

sub default_error_fh { \*STDERR }

=item * default_template

Returns the default template for output. In this modules, it's C<%c>,
for the city. See the L</Formats> section.

=cut

sub default_template ($app) { '%c' }

=item * default_output_fh

Returns the default for the error filehandle. In this module, it's
standard error.

=cut

sub default_output_fh { \*STDOUT }

=item * error(MESSAGE)

Send the MESSAGE string to the error filehandle.

=cut

sub error ($app, $message ) {
	say { $app->error_fh } $message
	}

=item * error_fh

Returns the filehandle for error output.

=cut

sub error_fh ($app) { $app->{error_fh} }

=item * formatter

Returns the formatter object. In this module, that's an object of
L<String::Sprintf>.

=cut

sub formatter ($app) {
	# $w - width of field
	# $v - value that corresponds to position in template
	# $V - list of all values
	# $l - letter
	my $formatter = String::Sprintf->formatter(
		a   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->asn
			},
		c   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->city
			},
		C   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->country
			},

		e   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->abuse
			},

		f   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->country_flag->{emoji};
			},

		h   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->hostname
			},

		i   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->ip
			},
		j   => sub ( $w, $v, $V, $l ) {
			use JSON;
			# we decode UTF-8 because it will be encoded again on the
			# way out
			decode( 'UTF-8', encode_json($V->[0]->TO_JSON) );
			},
		k   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s", $V->[0]->continent->{name}
			},


		L   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}f", $V->[0]->latitude
			},
		l   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}f", $V->[0]->longitude
			},

		n   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s", $V->[0]->country_name
			},

		o   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->org
			},
		r   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->region
			},

		t   => sub ( $w, $v, $V, $l ) {
			sprintf "%${w}s",  $V->[0]->timezone
			},

		N   => sub { "\n" },
		T   => sub { "\t" },
		'%' => sub { '%'  },
		);
	}

=item * format( TEMPLATE, IP_INFO )

Formats a L<Geo::Details> object according to template.

=cut

sub format ($app, $info) {
	state $formatter = $app->formatter;
	$formatter->sprintf( $app->template, $info );
	}

=item * get_info(IP_ADDRESS)

=cut

sub get_info ($app, $ip ) {
	state $ipinfo = Geo::IPinfo->new( $app->token );
	state $ipv4_pattern = $app->get_ipv4_pattern;
	state $ipv6_pattern = $app->get_ipv6_pattern;

	my $method = do {
		if( $ip =~ $ipv4_pattern ) {
			'info';
			}
		elsif( $ip =~ $ipv6_pattern ) {
			'info_v6'
			}
		else {
			$app->error( "<$ip> does not look like an IP address. Skipping." );
			next ARG;
			}
		};

	my $info = $ipinfo->$method($ip);

	unless( defined $info ) {
		$app->error( "Could not get info for <$ip>." );
		return;
		}

	$app->decode_info($info);

	return $info;
	}

=item * get_ipv4_pattern

Returns the regular expression that matches an IPv4 address.

=cut

sub get_ipv4_pattern ($app) {
	qr/
	\A
	(
		(\d+) (?: \. \d+ ){3}
	)
	\z
	/x;
	}

=item * get_ipv6_pattern

Returns the regular expression that matches an IPv6 address.

=cut

sub get_ipv6_pattern ($app) {
	qr/
	\A
	(
		[0-9:]+
	)
	\z
	/x;
	}

=item * get_token

Return the API token. So far, this is just the value in the C<APP_IPINFO_TOKEN>
environment variable.

=cut

sub get_token ($class) {
	$ENV{APP_IPINFO_TOKEN}
	}

=item * output(MESSAGE)

Send the MESSAGE string to the output filehandle.

=cut

sub output ($app, $message) {
	print { $app->output_fh } $message
	}

=item * output_fh

Return the filehandle for output.

=cut

sub output_fh ($app) { $app->{output_fh} }

=item * template

=cut

sub template ($app) { $app->{template} }

=item * token

Return the IPinfo.io token

=cut

sub token ($app) { $app->{token} }

=back

=head1 SEE ALSO

=over 4

=item * L<Geo::IPinfo>

=item * IPinfo.io, L<https://ipinfo.io>

=back

=head1 SOURCE AVAILABILITY

The main source repository is in Github, and there are backup repos
in other services:

=over 4

=item * L<https://github.com/briandfoy/app-ipinfo>

=item * L<https://bitbucket.org/briandfoy/app-ipinfo>

=item * L<https://gitlab.com/briandfoy/app-ipinfo>

=item * L<https://codeberg.org/briandfoy/app-ipinfo>

=back

=head1 COPYRIGHT

Copyright © 2025, brian d foy, all rights reserved.

=head1 LICENSE

You can use this code under the terms of the Artistic License 2.

=cut

__PACKAGE__;
