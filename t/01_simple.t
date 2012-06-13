use strict;
use warnings;
use utf8;
use Test::Base;
use JSON;
use lib 'lib';
use SQL::Mongo;
use Data::Dumper;
use Test::More;

plan tests => 1*blocks;

run {
    my $block = shift;
    my $dat = SQL::Mongo->convert_where($block->input);
    is_deeply($dat, JSON::decode_json($block->expected), $block->input)
        or note(Dumper $dat);
};

__END__

===
--- input: a = 'b'
--- expected: {"a":"b"}

===
--- input: a != 'b'
--- expected: { "a": { "$ne"    : "b" } }

===
--- input: a IN ('b', 'c')
--- expected: { "a": { "$in"    : [ "b", "c" ] } }

===
--- input: a NOT IN ('b', 'c')
--- expected: { "a": { "$nin"   : [ "b", "c" ] } }

===
--- input: a IS NULL
--- expected: { "a": { "$exists": 0 } }

===
--- input: a IS NOT NULL
--- expected: { "a": { "$exists": 1 } }

===
--- input: a < '1'
--- expected: { "a": { "$lt"    : 1 } }

===
--- input: a > '2'
--- expected: { "a": { "$gt"    : 2 } }

===
--- input: a <= '3'
--- expected: { "a": { "$lte"   : 3 } }

===
--- input: a >= '4'
--- expected: { "a": { "$gte"   : 4 } }

===
--- input: (a = 'b' AND a = 'd')
--- expected: { "$and": [ { "a": "b" }, { "a": "d" } ] }

===
--- input: (a = 'b' OR c = 'd')
--- expected: { "$or": [ { "a": "b" }, { "c": "d" } ] }

===
--- input: ((c = 'd' AND a = 'b') OR e = 'f')
--- expected: { "$or": [ { "$and": [{"c": "d"}, {"a": "b"}] }, { "e": "f" } ] }

===
--- input: (a = 'b' AND (c = 'd' OR e = 'f'))
--- expected: { "$and": [{"a": "b"}, {"$or": [ { "c": "d" }, { "e": "f" } ]}] }

===
--- input: ((c = 'd' AND a = 'b') OR (e = 'f' AND g = 'h'))
--- expected: { "$or": [ {"$and":[{ "c": "d"}, {"a": "b" }]}, { "$and": [{"e": "f"}, {"g": "h" }]} ] }

===
--- input: ((a = 'b' OR c = 'd') AND (e = 'f' OR g = 'h'))
--- expected: { "$and": [ { "$or": [ { "a": "b" }, { "c": "d" } ] }, { "$or" : [ { "e": "f" }, { "g": "h" } ] } ] }

