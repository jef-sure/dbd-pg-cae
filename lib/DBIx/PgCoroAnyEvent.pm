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
			while (!$dbh->pg_ready) {
				my $w;
				$w = AnyEvent->io(
					fh   => $dbh->{pg_socket},
					poll => 'r',
					cb   => sub {
						undef $w;
						$new->transfer($async);
					}
				);
				print "run once before statement: $sth->{Statement}\n";
				EV::run EV::RUN_ONCE;
			}
		};
		$async->transfer($new);
		$res = $dbh->pg_result;
		$res;
	}
}

1;
