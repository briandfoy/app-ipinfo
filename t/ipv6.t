use utf8;

use strict;
use warnings;
use open qw(:std :utf8);

use Test::More;

my $class  = 'App::ipinfo';
my $method = '_compact_ipv6';

my $ip = '1.1.1.1';

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $class, $method;
	};

subtest 'check that we can compact IPv6 addresses' => sub {
	my $sub = $class->can($method);

	is $sub->( '0:0:0:0:0:0:0:0' ), '::',              'null address is ::';
	is $sub->( '1:2:3:4:5:6:0:0' ), '1:2:3:4:5:6::',   'trailing zero';
	is $sub->( '0:0:2:3:4:5:6:7' ), '::2:3:4:5:6:7',   'leading zero';
	is $sub->( '1:2:3:0:0:5:6:7' ), '1:2:3::5:6:7',    'internal zero';
	is $sub->( '1:2:3:4:5:6:7:8' ), '1:2:3:4:5:6:7:8', 'internal zero';
	};


done_testing();
