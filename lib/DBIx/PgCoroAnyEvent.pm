{

	package DBIx::PgCoroAnyEvent;

=head1 NAME
 
DBIx::PgCoroAnyEvent - DBD::Pg + Coro + AnyEvent
 
=head1 SYNOPSIS
 
  use DBI;
  $dbh = DBI->connect("dbi:Pg:dbname=$dbname", $username, $auth, { RootClass =>"DBIx::PgCoroAnyEvent",  %rest_attr});

=cut

}
{

	package DBIx::PgCoroAnyEvent::db;
	use DBD::Pg ':async';
	use base 'DBD::Pg::db';
	use strict;
	use warnings;

	sub prepare {
		my ($dbh, $statement, @attribs) = @_;
		return undef if !defined $statement;
		$attribs[0]{pg_async} = PG_ASYNC + PG_OLDQUERY_WAIT;
		DBD::Pg::db::prepare($dbh, $statement, @attribs);
	}

	sub do {
		my ($dbh, $statement, $attr, @params) = @_;
		my $sth = $dbh->prepare($statement, $attr) or return undef;
		$sth->execute(@params) or return undef;
		my $rows = $sth->rows;
		($rows == 0) ? "0E0" : $rows;
	}
}

{

	package DBIx::PgCoroAnyEvent::st;
	use EV;
	use Coro;
	use AnyEvent;
	use Coro::AnyEvent;
	use base 'DBD::Pg::st';

	sub execute {
		my ($sth, @vars) = @_;
		my $res   = $sth->SUPER::execute(@vars);
		my $dbh   = $sth->{Database};
		my $async = new Coro::State;
		my $new;
		$new = new Coro::State sub {
			my $w;
			while (!$dbh->pg_ready) {
				$w = AnyEvent->io(
					fh   => $dbh->{pg_socket},
					poll => 'r',
					cb   => sub {
						if($dbh->pg_ready) {
							$w = undef;
							print "ready statement: $sth->{Statement}\n";
							$new->transfer($async);
						} 
					}
				) if not $w;
				print "run once in statement: $sth->{Statement}\n";
				EV::run EV::RUN_ONCE;
			}
			print "defined w: " . (defined $w? 'true': 'false') . "\n";
			print "finished statement: $sth->{Statement}\n??? how is this place reached???\n";
		};
		print "before async statement: $sth->{Statement}\n";
		$async->transfer($new);
		$new->cancel;
		print "after async statement: $sth->{Statement}\n";
		$res = $dbh->pg_result;
		$res;
	}
}

1;
