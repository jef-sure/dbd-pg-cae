requires 'DBD::Pg', ">= 1.44";
requires 'Coro';
requires 'AnyEvent';
requires 'Coro::AnyEvent';
requires 'Digest::MD5';
on 'test' => sub {
    requires 'Test::More';
    requires 'DBI';
    requires 'File::Temp';
    requires 'Time::HiRes';
};
on configure => sub {
    requires 'ExtUtils::MakeMaker';
};

