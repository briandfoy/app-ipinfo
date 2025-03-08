use strict;
use warnings;

use Test::More;

use lib qw(t/lib);

my $class = 'Local::ipinfo';
my $method = 'format';

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $class, 'new';

	my $app = $class->new;
	isa_ok $app, $class;
	can_ok $app, 'new', $method;
	};

subtest 'format' => sub {
	my $template = '%k';

	my $app = $class->new( template => $template );
	isa_ok $app, $class;

	my $info = $class->get_info('1.1.1.1');
	isa_ok $info, 'Geo::Details';

	my $s = $app->format($info);
	is $app->format($info), 'Oceania', 'output is correct';
	};

done_testing();
