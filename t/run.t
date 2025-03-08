use strict;
use warnings;

use Test::More;

use lib qw(t/lib);

my $class = 'Local::ipinfo';
my $method = 'run';

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $class, $method;
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
