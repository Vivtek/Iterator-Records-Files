#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;
use Iterator::Records::Files;
use Data::Dumper;

# Simple, non-role walk.
my $i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      sorted=>1,
   }
);
is_deeply ($i->fields(), [qw(path level item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)], 'field list check');
$i = $i->transmogrify(['select', 'path', 'level', 'name']);
#diag (Dumper($i->load()));
is_deeply ($i->load(),
[
 ['t/test_dir/.', 0, '.'],
 ['t/test_dir/..', 0, '..'],
 ['t/test_dir/.dot.txt', 0, '.dot.txt'],
 ['t/test_dir/.dotted', 0, '.dotted'],
 ['t/test_dir/00_test.ext', 0, '00_test.ext'],
 ['t/test_dir/README', 0, 'README'],
 ['t/test_dir/a_file.txt', 0, 'a_file.txt'],
 ['t/test_dir/folder', 0, 'folder'],
 ['t/test_dir/folder/.', 1, '.'],
 ['t/test_dir/folder/..', 1, '..'],
 ['t/test_dir/folder/content1.p', 1, 'content1.p'],
 ['t/test_dir/folder/content2.q', 1, 'content2.q'],
 ['t/test_dir/folder/subfolder', 1, 'subfolder'],
 ['t/test_dir/folder/subfolder/.', 2, '.'],
 ['t/test_dir/folder/subfolder/..', 2, '..'],
 ['t/test_dir/folder/subfolder/content3.ext', 2, 'content3.ext'],
 ['t/test_dir/this.txt', 0, 'this.txt']
]);

# Prune by maximum iteration level.
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      maxlevel=>1,
   }
);
$i = $i->transmogrify(['select', 'path', 'level', 'name']);
is_deeply ($i->load(),
[
 ['t/test_dir/.dot.txt', 0, '.dot.txt'],
 ['t/test_dir/.dotted', 0, '.dotted'],
 ['t/test_dir/00_test.ext', 0, '00_test.ext'],
 ['t/test_dir/README', 0, 'README'],
 ['t/test_dir/a_file.txt', 0, 'a_file.txt'],
 ['t/test_dir/folder', 0, 'folder'],
 ['t/test_dir/folder/content1.p', 1, 'content1.p'],
 ['t/test_dir/folder/content2.q', 1, 'content2.q'],
 ['t/test_dir/folder/subfolder', 1, 'subfolder'],
 ['t/test_dir/this.txt', 0, 'this.txt']
]);

# Prune with "nowalk" - which obviously is no longer a walk.
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      nowalk=>1,
   }
);
$i = $i->transmogrify(['select', 'path', 'level', 'name']);
is_deeply ($i->load(),
[
 ['t/test_dir/.dot.txt', 0, '.dot.txt'],
 ['t/test_dir/.dotted', 0, '.dotted'],
 ['t/test_dir/00_test.ext', 0, '00_test.ext'],
 ['t/test_dir/README', 0, 'README'],
 ['t/test_dir/a_file.txt', 0, 'a_file.txt'],
 ['t/test_dir/folder', 0, 'folder'],
 ['t/test_dir/this.txt', 0, 'this.txt']
]);

# Prune using a coderef tester
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      stopwalk=> [sub { $_[0] eq 'subfolder' }, 'name'],
   }
);
$i = $i->transmogrify(['select', 'path', 'level', 'name']);
is_deeply ($i->load(),
[
 ['t/test_dir/.dot.txt', 0, '.dot.txt'],
 ['t/test_dir/.dotted', 0, '.dotted'],
 ['t/test_dir/00_test.ext', 0, '00_test.ext'],
 ['t/test_dir/README', 0, 'README'],
 ['t/test_dir/a_file.txt', 0, 'a_file.txt'],
 ['t/test_dir/folder', 0, 'folder'],
 ['t/test_dir/folder/content1.p', 1, 'content1.p'],
 ['t/test_dir/folder/content2.q', 1, 'content2.q'],
 ['t/test_dir/folder/subfolder', 1, 'subfolder'],
 ['t/test_dir/this.txt', 0, 'this.txt']
]);
# Check no_level_field - note that maxlevel still works, because the level is being tracked internally, just not returned in the results.
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      no_level_field=>1,
      maxlevel=>1,
   }
);
is_deeply ($i->fields(), [qw(path item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)], 'field list check');
$i = $i->transmogrify(['select', 'path', 'name']);
is_deeply ($i->load(),
[
 ['t/test_dir/.dot.txt', '.dot.txt'],
 ['t/test_dir/.dotted', '.dotted'],
 ['t/test_dir/00_test.ext', '00_test.ext'],
 ['t/test_dir/README', 'README'],
 ['t/test_dir/a_file.txt', 'a_file.txt'],
 ['t/test_dir/folder', 'folder'],
 ['t/test_dir/folder/content1.p', 'content1.p'],
 ['t/test_dir/folder/content2.q', 'content2.q'],
 ['t/test_dir/folder/subfolder', 'subfolder'],
 ['t/test_dir/this.txt', 'this.txt']
]);

# Check no_path_field
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      no_path_field=>1,
   }
);
is_deeply ($i->fields(), [qw(level item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)], 'field list check');
$i = $i->transmogrify(['select', 'level', 'name']);
is_deeply ($i->load(),
[
 [0, '.dot.txt'],
 [0, '.dotted'],
 [0, '00_test.ext'],
 [0, 'README'],
 [0, 'a_file.txt'],
 [0, 'folder'],
 [1, 'content1.p'],
 [1, 'content2.q'],
 [1, 'subfolder'],
 [2, 'content3.ext'],
 [0, 'this.txt']
]);

# Let's do that, only with the transmogrifiers *inside* the spec.
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      no_path_field=>1,
      transmogrify => [['select', 'level', 'name']],
   }
);
is_deeply ($i->load(),
[
 [0, '.dot.txt'],
 [0, '.dotted'],
 [0, '00_test.ext'],
 [0, 'README'],
 [0, 'a_file.txt'],
 [0, 'folder'],
 [1, 'content1.p'],
 [1, 'content2.q'],
 [1, 'subfolder'],
 [2, 'content3.ext'],
 [0, 'this.txt']
]);

# Now let's test a few vanilla roledir walks - first let's just check the field list created if a role ruleset is present.
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
      ]
   }
);
is_deeply ($i->fields(), [qw(path level role item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks value_bag)], 'field list check');
$i = $i->transmogrify(['select', 'path', 'level', 'name']);
#diag (Dumper($i->load()));

# Try a transmogrified walk with role identification and value extraction
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
      ],
      transmogrify => [
         ['getvalue', 'prefix'],
         ['select', 'level', 'role', 'prefix', 'name'],
      ]
   }
);
#diag (Dumper($i->load()));
is_deeply ($i->load(),
[
 [0, '',      undef, '.dot.txt'],
 [0, '',      undef, '.dotted'],
 [0, 'ufile', '00',  '00_test.ext'],
 [0, '',      undef, 'README'],
 [0, 'ufile', 'a',   'a_file.txt'],
 [0, '',      undef, 'folder'],
 [1, '',      undef, 'content1.p'],
 [1, '',      undef, 'content2.q'],
 [1, '',      undef, 'subfolder'],
 [2, '',      undef, 'content3.ext'],
 [0, '',      undef, 'this.txt']
]);

# Find everything with an ".ext" extension
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['extfile', ['ext', 'ext' ]],
      ],
      transmogrify => [
         ['where', sub { $_[0] eq 'extfile' }, 'role'],
         ['select', 'path', 'level', 'name']
      ]
   }
);
#diag (Dumper($i->load()));
is_deeply ($i->load(),
[
 ['t/test_dir/00_test.ext',                   0, '00_test.ext'],
 ['t/test_dir/folder/subfolder/content3.ext', 2, 'content3.ext']
]);

# Find everything with a defined role
$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roles=>[ ['ufile', ['match', qr/^(.*)_/, 'prefix' ]],
               ['extfile', ['ext', 'ext' ]]
             ],
      transmogrify => [
         ['where',    sub { $_[0] }, 'role'],
         ['getvalue', 'prefix'],
         ['select',   'role', 'level', 'prefix', 'name']
      ]
   }
);
#diag (Dumper($i->load()));
is_deeply ($i->load(),
[
 ['ufile',   0, '00',  '00_test.ext'], # Note 'ufile' matches first, thus defines the role even though this file would match either rule.
 ['ufile',   0, 'a',   'a_file.txt'],
 ['extfile', 2, undef, 'content3.ext']
]);


# Finally, the culminating effort: a walk in which the roles of directories determine the rules and parameters for the walk as it continues
# inside them.

$i = Iterator::Records::Files->walk (
   't/test_dir',
   {
      clean=>1,
      sorted=>1,
      roleparms =>
      {
         special => {
            roles=>[ ['pfile', ['ext', 'p']],
                     ['specialext', ['ext', 'ext']]
                   ]
         },
      },
      roles=>[ ['special', ['dir']],
               ['extfile', ['ext', 'ext' ]]
             ],
      transmogrify => [
         ['select',   'role', 'level', 'name']
      ]
   }
);
#diag (Dumper($i->load()));
is_deeply ($i->load(),
[
 ['',        0, '.dot.txt'],
 ['',        0, '.dotted'],
 ['extfile', 0, '00_test.ext'],
 ['',        0, 'README'],
 ['',        0, 'a_file.txt'],
 ['special', 0, 'folder'],
 ['pfile',   1, 'content1.p'],
 ['',        1, 'content2.q'],
 ['',        1, 'subfolder'],
 ['specialext', 2, 'content3.ext'],
 ['',        0, 'this.txt']
]);


done_testing();
