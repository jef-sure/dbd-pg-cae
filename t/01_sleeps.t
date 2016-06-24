use lib qw'../lib lib t';
use Test::More;
use DBI;
use EV;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use Time::HiRes 'time';

sub db_connect {
	DBI->connect(
		"dbi:Pg:dbname=anton",
		"anton", "",
		{   AutoCommit => 1,
			RootClass  => 'DBIx::PgCoroAnyEvent'
		}
	);
}

my $cv = AE::cv;

ok(my $dbh = db_connect(), 'connected');
ok(my $sth = $dbh->prepare('select pg_sleep(2)'), 'prepared');
my $start_time = time;
ok($sth->execute(), 'executed');
my $duration = time - $start_time;
ok(($duration > 1 && $duration < 3), 'slept');
is(ref($dbh), 'DBIx::PgCoroAnyEvent::db', 'dbh class');
is(ref($sth), 'DBIx::PgCoroAnyEvent::st', 'sth class');
my $status   = 0;
my $finished = 0;

for my $t (1 .. 10) {
	$finished += 1 << $t;
}

for my $t (1 .. 10) {
	my $timer;
	$timer = AE::timer 0.01 + $t/100, 0, sub {
		ok(my $dbh = db_connect(), "connected $t");
		ok(my $sth = $dbh->prepare('select pg_sleep(' . $t . ')'), "prepared $t");
		my $start_time = time;
		ok($sth->execute(), "executed $t");
		my $duration = time - $start_time;
		ok(($duration > $t - 1 && $duration < $t + 1), "slept $t");
		print "duration: $t: $duration\n";
		$status += 1 << $t;
		if ($status == $finished) {
			$cv->send;
		}
		undef $timer;
	};
}

$cv->recv;

print "total run time: " . (time - $start_time) . " sec\n";

done_testing();
