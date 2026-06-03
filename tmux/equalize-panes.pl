#!/usr/bin/perl
# Equalize tmux pane sizes WITHOUT changing the layout structure.
#
# tmux's built-in `select-layout even-horizontal|even-vertical|tiled` all rebuild
# the pane tree, which reorders/reorients panes. Instead we parse the current
# window_layout, redistribute sizes so siblings are equal at every nesting level,
# and re-apply the rewritten layout string — preserving the exact tree.
#
# Test mode:  perl equalize-panes.pl '<layout-string>'   -> prints new layout
# Run mode:   perl equalize-panes.pl                      -> reads & applies via tmux
use strict;
use warnings;

my $str;  # layout body (checksum stripped); parsed with \G / pos()

# Recursive-descent parse of a layout cell: "WxH,X,Y" then optional {..}/[..]/,pane
sub parse_cell {
    $str =~ /\G(\d+)x(\d+),(\d+),(\d+)/gc or die "bad dims in layout\n";
    my $n = { w => $1, h => $2, x => $3, y => $4 };
    if ($str =~ /\G\{/gc) {
        $n->{type} = 'h';
        $n->{kids} = [ parse_children('}') ];
    } elsif ($str =~ /\G\[/gc) {
        $n->{type} = 'v';
        $n->{kids} = [ parse_children(']') ];
    } elsif ($str =~ /\G,(\d+)/gc) {
        $n->{type} = 'leaf';
        $n->{pane} = $1;
    } else {
        $n->{type} = 'leaf';
    }
    return $n;
}

sub parse_children {
    my ($close) = @_;
    my @kids = ( parse_cell() );
    push @kids, parse_cell() while $str =~ /\G,/gc;
    $str =~ /\G\Q$close\E/gc or die "expected '$close'\n";
    return @kids;
}

# Resize node to (x,y,w,h) and split that space equally among children.
# tmux reserves 1 row/col for the divider between adjacent siblings.
sub equalize {
    my ($n, $x, $y, $w, $h) = @_;
    @{$n}{qw(x y w h)} = ($x, $y, $w, $h);
    return if $n->{type} eq 'leaf';

    my @k   = @{ $n->{kids} };
    my $cnt = scalar @k;

    if ($n->{type} eq 'h') {
        my $avail = $w - ($cnt - 1);
        my ($base, $rem) = (int($avail / $cnt), $avail % $cnt);
        my $cur = $x;
        for my $i (0 .. $cnt - 1) {
            my $cw = $base + ($i < $rem ? 1 : 0);
            equalize($k[$i], $cur, $y, $cw, $h);
            $cur += $cw + 1;
        }
    } else {  # 'v'
        my $avail = $h - ($cnt - 1);
        my ($base, $rem) = (int($avail / $cnt), $avail % $cnt);
        my $cur = $y;
        for my $i (0 .. $cnt - 1) {
            my $ch = $base + ($i < $rem ? 1 : 0);
            equalize($k[$i], $x, $cur, $w, $ch);
            $cur += $ch + 1;
        }
    }
}

sub serialize {
    my ($n) = @_;
    my $d = "$n->{w}x$n->{h},$n->{x},$n->{y}";
    return "$d,$n->{pane}"        if $n->{type} eq 'leaf';
    my $inner = join ',', map { serialize($_) } @{ $n->{kids} };
    return $n->{type} eq 'h' ? "$d\{$inner\}" : "$d\[$inner\]";
}

# tmux layout checksum (layout_custom.c: rotate-right then add each byte, u_short).
sub checksum {
    my ($l) = @_;
    my $c = 0;
    for my $ch (split //, $l) {
        $c = (($c >> 1) | (($c & 1) << 15)) & 0xffff;
        $c = ($c + ord $ch) & 0xffff;
    }
    return sprintf '%04x', $c;
}

my $test = @ARGV ? 1 : 0;
my $input = $test ? $ARGV[0] : `tmux display -p '#{window_layout}'`;
chomp $input;
$input =~ s/^[0-9a-f]{4},// or die "no checksum prefix: $input\n";

$str = $input;
my $root = parse_cell();
equalize($root, $root->{x}, $root->{y}, $root->{w}, $root->{h});
my $body = serialize($root);
my $out  = checksum($body) . ",$body";

if ($test) { print "$out\n"; }
else       { system 'tmux', 'select-layout', $out; }
