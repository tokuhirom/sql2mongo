package SQL::Mongo;
use strict;
use warnings;
use utf8;
use 5.16.0;
use Carp;
use Data::Dumper;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub convert_where {
    my $class = shift;
    my $where = shift;

    my ($c, $ret) = _where_clause($where);
    if ($c =~ /\S/) {
        die "Parse failed: $c";
    }
    return $ret;
}

sub _where_clause {
    my $c = shift;

    _logical_expression($c);
}

sub _any {
    my $src = shift;
    for (@_) {
        my @a = $_->($src);
        return @a if @a;
    }
    return ();
}

# see http://en.wikipedia.org/wiki/Parsing_expression_grammar#Indirect_left_recursion
# %left operator.
sub _left_op {
    my ($upper, $ops) = @_;
    confess "\$ops must be HashRef" unless ref $ops eq 'HASH';

    sub {
        my $c = _skip_ws(shift);
        ($c, my $lhs) = $upper->($c)
            or return;
        my $ret = $lhs;
        while (1) {
            my ($used, $token_id) = _token_op($c);
            last unless $token_id;

            my $code = $ops->{$token_id}
                or last;

            $c = substr($c, $used);
            ($c, my $rhs) = $upper->($c)
                or die "syntax error  after '$token_id'";
            $ret = $code->($lhs, $rhs);
        }
        return ($c, $ret);
    }
}

sub _token_op {
    my $c = shift;
    $c =~ s/^(\s*(,|!=|<=|>=|[<>=]|AND|OR))//i
        and return (length($1), uc($2));
    return;
}

sub _skip_ws {
    my $c = shift;
    $c =~ s/^\s+//;
    $c;
}

*_logical_expression = _left_op(
    \&_equal_expression, +{
        'AND' => sub {
            +{
                '$and' => [
                    $_[0], $_[1]
                ]
            };
        },
        'OR' => sub {
            +{
                '$or' => [
                    $_[0], $_[1]
                ]
            };
        },
    }
);

sub _equal_expression {
    _left_op(
        \&_in_expression, {
            '=' => sub {
                +{
                    $_[0] => $_[1]
                };
            },
            '!=' => sub {
                +{
                    $_[0] => +{ '$ne' => $_[1] },
                };
            },
            '<' => sub {
                +{
                    $_[0] => +{ '$lt' => $_[1] },
                };
            },
            '>' => sub {
                +{
                    $_[0] => +{ '$gt' => $_[1] },
                };
            },
            '<=' => sub {
                +{
                    $_[0] => +{ '$lte' => $_[1] },
                };
            },
            '>=' => sub {
                +{
                    $_[0] => +{ '$gte' => $_[1] },
                };
            },
        },
    )->(@_);
}

sub _in_expression {
    my $c = shift;
    _any(
        $c,
        sub {
            my $c = shift;
            ($c, my $lhs) = _is_null_expression($c)
                or return;
            $c = _skip_ws($c);
            $c =~ s/^(NOT\s+)?IN\s*\(//i
                or return;
            my $type = $1 ? '$nin' : '$in';
            my @list;
            while (1) {
                $c = _skip_ws($c);
                if ($c =~ s/^\)//) {
            EOF:
                    return ($c, +{
                        $lhs => +{ $type => \@list }
                    });
                } else {
                    ($c, my $elem) = _is_null_expression($c)
                        or die "Syntax error in IN clause";
                    push @list, $elem;
                    $c =~ s/^\)//
                        and goto EOF;
                    $c =~ s/^\s*,\s*//
                        or die "Syntax error in IN clause";
                }
            }
        },
        \&_is_null_expression,
    );
}

sub _is_null_expression {
    my $c = shift;
    _any(
        $c,
        sub {
            my $c = shift;
            ($c, my $lhs) = _primary($c)
                or return;
            $c = _skip_ws($c);
            $c =~ s/^IS(\s+NOT)?\s+NULL//i
                and return ($c, +{ $lhs => { '$exists' => $1 ? 1 : 0 } });
            return;
        },
        \&_primary,
    );
}

sub _primary {
    my $c = shift;
    _any(
        $c,
        sub { # ident
            my $c = _skip_ws(shift);
            $c =~ s/^([A-Za-z_][A-Za-z0-9_]*)//
                and return ($c, $1);
            return;
        },
        sub { # string
            my $c = _skip_ws(shift);
            $c =~ s/^(["'])//
                or return;
            my $close = $1;
            my $ret = '';
            while (length $c > 0) {
                $c =~ s/^$close//
                    and do {
                        return ($c, $ret);
                    };
                $c =~ s/^\\"//
                    and do {
                        $ret .=  q{"}
                    };
                $c =~ s/^\\'//
                    and do {
                        $ret .=  q{'}
                    };
                $c =~ s/^(.)//
                    and do {
                        $ret .= $1;
                    };
            }
            die "Unexpected EOF in string literal";
        },
        sub { # parens
            my $c = _skip_ws(shift);
            $c =~ s/^\(//
                 or return;
            ($c, my $inner) = _logical_expression($c)
                or return;
            $c = _skip_ws($c);
            $c =~ s/^\)//
                or return;
            return ($c, $inner);
        },
    );
}

1;

