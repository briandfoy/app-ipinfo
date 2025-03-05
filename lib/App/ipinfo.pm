#!perl
use v5.20;
use strict;
use open qw(:std :utf8);

use experimental qw(signatures);

package App::IPinfo;

use Geo::IPinfo;
use Encode qw(decode);
use String::Sprintf;

__PACKAGE__->run(@ARGV) unless caller();

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Class methods

=over 4

=item * new(TOKEN)

=cut

sub new ($class, %hash) {
	state $defaults => {
		output_fh => $class->default_output_fh,
		error_fh  => $class->default_error_fh,
		format    => $class->default_format,
		};

	my %args = ( $defaults->%*, %hash );

	bless \%args, $class;
	}

=item * CLASS->run( [FORMAT,] IP_ADDRESS [, IP_ADDRESS ... ] )

=item * OBJ->run( [FORMAT,] IP_ADDRESS [, IP_ADDRESS ... ] )

Format every IP address according to FORMAT and send the result to
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

sub run ($either, @args) {
	my $app = ref $either ? $either : $either->new($ENV{IPINFO_TOKEN});

	my $format = do {
		if( $args[0] =~ /%/ ) {
			shift @args;
			}
		else {
			$ENV{APP_IPINFO_FORMAT} // $app->default_format;
			}
		};

	my $ipinfo = Geo::IPinfo->new( $app->token // () );

	state $ipv4_pattern = $app->get_ipv4_pattern;
	state $ipv6_pattern = $app->get_ipv6_pattern;

	ARG: foreach my $arg (@args) {
		my $method = do {
			if( $arg =~ $ipv4_pattern ) {
				'info';
				}
			elsif( $arg =~ $ipv6_pattern ) {
				'info_v6'
				}
			else {
				$app->error( "<$arg> does not look like an IP address. Skipping." );
				next ARG;
				}
			};

		my $info = $ipinfo->$method($arg);
		$app->decode_info($info);

		unless( defined $info ) {
			$app->error( "Could not get info for <$arg>." );
			next ARG;
			}

		$app->output( $app->format( $format, $info ) );
		}
	}

=back

=head2 Instance methods

=over 4

=item *

=cut

sub decode_info ($app, $info) {
	my @queue = $info;

	ITEM: while( my $i = shift @queue ) {
		KEY: foreach my $key ( keys $i->%* ) {
			if( ref $i->{$key} ) {
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

=item * default_format

Returns the default template for output. In this modules, it's C<%c>,
for the city. See the L</Formats> section.

=cut

sub default_format ($app) { '%c' }

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
			sprintf "%${w}s", $V->[0]->continent
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

sub format ($app, $template, $info) {
	state $formatter = $app->formatter;
	$formatter->sprintf( $template, $info );
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

=item * output(MESSAGE)

Send the MESSAGE string to the output filehandle.

=cut

sub output ($app, $message) {
	say { $app->output_fh } $message
	}

=item * output_fh

Return the filehandle for output.

=cut

sub output_fh ($app) { $app->{output_fh} }

=item * token

Return the IPinfo.io token

=cut

sub token ($app) { $app->{token} }

=back

=head1 SEE ALSO

=over 4

=item * L<Geo::IPinfo>

=item * IPinfo.io, L<https://ipinfo.io>

=cut

=head1 SOURCE AVAILABILITY


=head1 COPYRIGHT

Copyright © 2020-2025, brian d foy, all rights reserved.

=head1 LICENSE

You can use this code under the terms of the Artistic License 2.

=cut


=cut

__PACKAGE__;
