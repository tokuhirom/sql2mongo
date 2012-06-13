use strict;
use warnings;
use utf8;
use Test::More;
use SQL::Mongo;

is_deeply([SQL::Mongo::_primary(q{'b'})], ['', 'b']);

done_testing;

