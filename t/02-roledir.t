#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;
use Iterator::Records::Files;
use Data::Dumper;

# Let's find the role and name for everything the test directory, where files have role "file" and directories role "d".
my $i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['file', ['file']],
               ['d',    ['dir']],
             ]
   }
);
is_deeply ($i->fields(), [qw(role item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks value_bag)], 'field list check');

$i = $i->transmogrify(['select', 'role', 'name']);
is_deeply ($i->load(), [['file', '.dot.txt'], ['file', '.dotted'], ['file', '00_test.ext'], ['file', 'README'], ['file', 'a_file.txt'], ['d', 'folder'], ['file', 'this.txt']]);

# Let's find the name of every file with an "ext" extension. (The trick: non-matched entries will have role '', which we can filter out with a 'where' transmogrifier.)
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['efile', ['ext', 'ext']],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name']);
is_deeply ($i->load(), [['00_test.ext']]);

# Let's find the name of every file with a "txt" extension.
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['text', ['ext', 'txt']],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name']);
is_deeply ($i->load(), [['.dot.txt'], ['a_file.txt'], ['this.txt']]);

# Let's use a generic calc rule to find the name of every file that has an underscore in it.
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['calc', sub { $_[0] =~ /_/; }, 'name' ]],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name']);
#diag(Dumper($i->load()));
is_deeply ($i->load(), [['00_test.ext'], ['a_file.txt']]);

# Now let's return a value bag value from calc.
sub complex_tester {
   my $name = shift;
   if ($name =~ /^(.*)_/) {
      return { prefix => $1 };
   } else {
      return 0;
   }
}
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['calc', \&complex_tester, 'name' ]],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name', 'value_bag']);
#diag(Dumper($i->load()));
is_deeply ($i->load(), [['00_test.ext', { prefix => '00' }], ['a_file.txt', { prefix => 'a'}]]);

# Now let's do that exact same thing, but with an actual match rule.
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name', 'value_bag']);
#diag(Dumper($i->load()));
is_deeply ($i->load(), [['00_test.ext', { prefix => '00' }], ['a_file.txt', { prefix => 'a'}]]);

# And now let's use the getvalue transmogrifier to promote our prefix up into the record (equivalent to ['gethashval', 'value_bag', 'prefix'])
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['getvalue', 'prefix'], ['select', 'name', 'prefix']);
#diag(Dumper($i->load()));
is_deeply ($i->load(), [['00_test.ext', '00'], ['a_file.txt', 'a']]);


# Now let's do that, only in a single step:
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
             ],
      transmogrify => [['where', sub { $_[0] }, 'role'], ['getvalue', 'prefix'], ['select', 'name', 'prefix']],
   }
);
is_deeply ($i->load(), [['00_test.ext', '00'], ['a_file.txt', 'a']]);



# Let's check that the generic calc rule will croak if given a bad name for a file field.
$i = Iterator::Records::Files->roledir (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['calc', sub { $_[0] =~ /_/; }, 'blurg' ]],
             ]
   }
)->transmogrify(['where', sub { $_[0] }, 'role'], ['select', 'name']);

# Note that for role calculations this only happens when we try to run the calculator, not when we define it. (Still might be a bad choice.)
ok (not eval { $i->load(); });
like ($@, qr/Unknown field 'blurg' used in role calculation rule/, 'error message identifies bad field name in role calc clause');


# Let's verify that we croak on an unknown role calc clause.
$i = Iterator::Records::Files->roledir (
    't/test_dir',
    {
       clean=>1,
       sorted=>1,
       roles=>[ ['text', ['wrong thing', 'txt']],
              ]
    }
);
ok (not eval { $i->load(); }); 
like ($@, qr/Unknown role calc rule 'wrong thing'/, 'error message identifies unknown role calc clause');



done_testing();
