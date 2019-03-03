#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;
use Iterator::Records::Files;
use Data::Dumper;

my $i = Iterator::Records::Files->readdir_q ('t/test_dir', {clean=>1});
is_deeply ($i->fields(), [qw(item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)], 'field list check');

$i = $i->transmogrify(['select', 'name']);
my $data = $i->load();
is (scalar(@$data), 7, 'unsorted readdir');

$i = Iterator::Records::Files->readdir_q ('t/test_dir', {sorted=>1})->transmogrify(['select', 'name', 'ext']);
#diag(Dumper($i->load()));
is_deeply ($i->load(), [['.', ''], ['..', ''], ['.dot.txt', 'txt'], ['.dotted', ''], ['00_test.ext', 'ext'], ['README', ''], ['a_file.txt', 'txt'], ['folder', ''], ['this.txt', 'txt']], 'sorting and extensions');
$i = Iterator::Records::Files->readdir_q ('t/test_dir', {clean=>1, sorted=>sub{lc($_[0]) cmp lc($_[1])}})->transmogrify(['select', 'name']);
is_deeply ($i->load(), [['.dot.txt'], ['.dotted'], ['00_test.ext'], ['a_file.txt'], ['folder'], ['README'], ['this.txt']], 'clean and sorting with custom sorter');

$i = Iterator::Records::Files->readdir_q ('t/test_dir', {sorted=>1})->transmogrify(['select', 'name', 'item'], ['where', sub { $_[0] eq '+' }, 'item']);
is_deeply ($i->load(), [['.', '+'], ['..', '+'], ['folder', '+']]);

$i = Iterator::Records::Files->readdir_q ('t/test_dir', {sorted=>1, transmogrify=>[['select', 'name', 'item'], ['where', sub { $_[0] eq '+' }, 'item']]});
is_deeply ($i->load(), [['.', '+'], ['..', '+'], ['folder', '+']]);


done_testing();
