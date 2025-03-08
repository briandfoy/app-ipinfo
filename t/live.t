use utf8;

use strict;
use warnings;
use open qw(:std :utf8);

use Test::More;

plan skip_all => 'set APP_IPINFO_TOKEN for live tests'
	unless defined $ENV{'APP_IPINFO_TOKEN'};

my $class  = 'App::ipinfo';
my $method = 'new';

my $ip = '151.101.130.132';

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $class, $method;
	};

subtest 'run, class' => sub {
	open my $stdout, '>:raw', \ my $out;
	my $rc = $class->run({
		token     => $ENV{'APP_IPINFO_TOKEN'},
		output_fh => $stdout,
		template  => '%c',
		},
		$ip
		);

	close $stdout;

	is $out, 'San Francisco', 'output is expected';
	};

subtest 'run, class, bad ip' => sub {
	open my $stdout, '>:raw', \ my $out;
	open my $stderr, '>:raw', \ my $err;

	my $rc = $class->run({
		token     => $ENV{'APP_IPINFO_TOKEN'},
		output_fh => $stdout,
		error_fh  => $stderr,
		template  => '%c',
		},
		'257.0.0.1'
		);

	close $stdout;
	close $stderr;

	is $out, undef, 'output is not defined';
	like $err, qr/Could not get info/, 'output is expected';
	};

subtest 'run, app' => sub {
	open my $stdout, '>:raw', \ my $out;
	open my $stderr, '>:raw', \ my $err;

	my $app = $class->new(
		token     => $ENV{'APP_IPINFO_TOKEN'},
		output_fh => $stdout,
		error_fh  => $stderr,
		template  => '%c',
		);
	isa_ok $app, $class;

	my $rc = $app->run( $ip );

	close $stdout;
	close $stderr;

	is $out, 'San Francisco', 'output is expected';
	is $err, undef, 'error is not defined';
	};

subtest 'run with string fh' => sub {
	my $template = '%r';

	my( $out, $err );

	{
	open my $stdout, '>:encoding(UTF-8)', \ $out;
	open my $stderr, '>:encoding(UTF-8)', \ $err;

	can_ok $stdout, qw(print);

	my $rc = $class->run(
		{
		template  => $template,
		output_fh => $stdout,
		error_fh  => $stderr,
		},
		qw(1.1.1.1)
		);
	}

	is $out, 'Queensland', 'output is correct';
	};

done_testing();
