package Iterator::Records::Files;

use 5.006;
use strict;
use warnings;
use Carp;
use File::Spec::Functions;
use File::Basename;
use Iterator::Simple qw(iterator);
use Iterator::Records;
use Data::Dumper;

=head1 NAME

Iterator::Records::Files - a record iterator that provides information about files

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

L<Iterator::Records> provides convenient tools for working with "record streams", that is, iterators guaranteed to return arrayrefs with known fields analogous
to the records returned from an SQL database. Within that ecosystem, there could be any number of useful record streams that go beyond SQL databases and in-memory
data structures; the file system is one such source, and Iterator::Records::Files provides query tools for the filesystem that play well with L<Iterator::Records>.

=head1 SPECIFICATION

A file iterator, like any other Iterator::Records object, is a factory for making iterators. Given a definition of what to iterate, therefore, we can ask for
an iterator that does that. The specification of such an iterator is a little complicated, because there are a lot of things we often want to do with filesystems.

=head1 CHECKING A FILE

=head2 check (file), check_hash (file)

Given the path of a directory/file, checks for existence and runs stat on it if it does exist. It's a convenient shortcut for
C<scan([$file,'F'])>. Returns an arrayref with the filetype (the first character of the modestr), the modestr for the file as
ls would display it under Unix, followed by all the values returned from stat.

If the file doesn't actually exist, its type is '!' and its modestr is '!---------', and all the stat fields are set to 0.

The C<check_hash> variant just puts all the values from C<check> into a hashref for convenience if, like me, you can't be
bothered to look up the positions of all those fields.

=cut

sub check {
    my ($self, $file) = @_;
    
    my @stat = stat($file);
    return ['!', '!---------', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] unless @stat;

    # This bit is shamelessly stolen from Stat::lsMode because I don't want all its overhead.
    # Not to mention it was written in 1998 and doesn't pass smoke on Windows.
    # But it remains the definitive way to get a pretty modestring.
    my $mode = $stat[2];
    my $setids = ($mode & 07000)>>9;
    my @permstrs = qw(--- --x -w- -wx r-- r-x rw- rwx)[($mode&0700)>>6, ($mode&0070)>>3, $mode&0007];
    my $ftype = qw(. p c ? d ? b ? - ? l ? s ? ? ?)[($mode & 0170000)>>12];
    if ($setids) {
       if ($setids & 01) {		# Sticky bit
          $permstrs[2] =~ s/([-x])$/$1 eq 'x' ? 't' : 'T'/e;
       }
       if ($setids & 04) {		# Setuid bit
          $permstrs[0] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
       }
       if ($setids & 02) {		# Setgid bit
          $permstrs[1] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
       }
    }
    
    [$ftype eq 'd' ? '+' : '-', join ('', $ftype, @permstrs), @stat];
}
sub check_hash {
   my ($self, $file) = @_;
   my @check = $self->check($file);
   my $ret = {};
   foreach my $f (qw(filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)) {
      $ret->{$f} = shift @check;
   }
   $ret;
}


=head2 readdir (dir, parms), readdir_q (dir, parms)

The basic core of any filesystem iterator is simply a directory reader. This is the building block that everything else builds on, but it's also exposed for
quick reading of a given directory. The default is of course the current directory.

The fields returned from this iterator are always the following:

=over
=item item: this is a + or - indicating whether the item is a directory or a file. Soft links are directories at this level.
=item name, ext, dir: the name of the file or directory, any extension (i.e. anything after a dot), and the directory passed in.
=item filetype, modestr: the modestr is a reconstruction of what you'd see from ls under Unix, and the filetype here is the first letter of that modestr.
=item dev, ino, mode, nlink, uid, gid, rdev, size, atime, mtime, ctime, blksize, blocks: the fields returned from stat.
=back

The last two categories are just the fields returned from C<check>, of course.

The return value from this is an L<Iterator::Simple> iterator, not an iterator factory. To get an L<Iterator::Records> object, use C<readdir_q>.

The parameters are an optional hashref with the following:

=over
=item sorted - either a coderef specifying a comparator, or a 1 to use the default C<{$a cmp $b}> string sort.
=item clean - if true, removes '.' and '..' from the list.
=cut

sub readdir {
   my ($self, $dir, $parms) = @_;
   
   $dir = '.' unless defined $dir;
   $parms = {} unless defined $parms;
   my $clean = $parms->{clean} || 0;
   my $sorted = $parms->{sorted} || 0;
   
   return iterator { undef; } unless -e $dir;
   return iterator { undef; } unless -d $dir;
   return $self->readdir_sorted($dir, $clean, $sorted) if $sorted;
   
   opendir (my $dh, $dir) || croak "Can't open directory $dir: $!";
   my $done = 0;
   
   iterator {
      ANOTHER:
      return undef if $done;
      my $next = CORE::readdir($dh);
      if (not $next) {
         $done = 1;
         closedir ($dh);
         return undef;
      }
      
      goto ANOTHER if $clean and $next =~ /^\.+$/;
      my ($fname, $nvm, $ext) = fileparse ($next, qr/\.[^.]*/);
      $ext = '' if $ext eq $next;
      $ext =~ s/\.//;
      my $check = $self->check(catfile($dir, $next));
      [$check->[0], $next, $ext, $dir, @$check];
   }
}

sub file_fields { qw(item name ext dir filetype modestr dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks); }

sub readdir_q {
   my ($self, $dir, $parms) = @_;
   my $transmogrifiers = $parms->{'transmogrify'};
   my $sub = sub {
      $self->readdir($dir, $parms);
   };
   my $base_iter = Iterator::Records::Files::Iterator->new ($sub, [file_fields()]);
   if ($transmogrifiers) {
      return $base_iter->transmogrify(@$transmogrifiers);
   } else {
      return $base_iter;
   }
}


sub readdir_sorted {
   my ($self, $dir, $clean, $sorted) = @_;
   $sorted = sub {$_[0] cmp $_[1]} unless ref $sorted and ref($sorted) eq 'CODE';

   opendir (my $dh, $dir) || croak "Can't open directory $dir: $!";
   my @list = sort {$sorted->($a, $b)} CORE::readdir ($dh);
   closedir ($dh);
   
   iterator {
      ANOTHER:
      return undef unless scalar(@list);
      my $next = shift @list;
      goto ANOTHER if $clean and $next =~ /^\.+$/;
      
      my ($fname, $nvm, $ext) = fileparse ($next, qr/\.[^.]*/);
      $ext = '' if $ext eq $next;
      $ext =~ s/\.//;
      my $check = $self->check(catfile($dir, $next));
      [$check->[0], $next, $ext, $dir, @$check];
   }
}

=head1 ROLES

Each item (file or directory) in a walk can have a I<role>, effectively the type of file. The role will be used later to affect how a walk is done,
as directories that fulfill different roles can have different pruning behavior and their contents can have different role determination rules.

The role calculator has two outputs, though - not only the role of the item examined, but also an optional hashref of values determined from its filename.
As an example, say we have test files of the form 00_load.t and 01_more.t. A possible match pattern could be C<[qr/^(\d+)_(.*)\.t], 'number', 'name']>, which
would not only match this filename, but add values to the value bag of C<number=00> and C<name=load> for the first file and C<number=01> and C<name=more> for
the second. (There is a value extraction transmogrifier to get those values into record fields if you need them there.)

A complete role calculator specification looks like this:
  [  ['role1', ['match', qr/^a/]],
     ['role2', ['ext', 'txt', 'pl']]]

In other words, it's a list of arrayrefs, each of which starts with a role name and can have a series of tests. Each test is an arrayref consisting of
a name and a list of parameters. If a role has multiple tests, all must hit for the role to apply; if not, the calculator goes to the next role and tries
that one. A role without parameters will always match; obviously, it should be the last role in the list. If no role matches (there's no default) then
the role will simply be a blank string.

The possible tests are:

C<calc> applies an arbitrary coderef to the named fields of the item's record, exactly like the 'calc' transmogrifier in L<Iterator::Records>. Unlike that
transmogrifer, the 'calc' test can return an arbitrary hashref that will be placed into the value bag.

C<match> applies a regex to the filename. If the regex has () fields, they'll be put into the named values in the value bag, but that's optional.

C<name> matches a specific list of names (without extension).

C<ext> matches a specific list of extensions.

C<dir> matches any directory, no parameters.

C<file> matches any non-directory, no parameters.

Note that the entire C<stat> information for the file is available, but you need to write a calc test to use it; there are no handy abbreviations.

=head2 roledir (dir, parms)

The C<roledir> function takes the same parameters as C<readdir_q> because it actually builds a readdir iterator and then internally transmogrifies it
with the ruleset provided. The role calculator itself is implemented as a transmogrifier that can only be applied to a Files record stream. It's probably
only marginally safe to use it by hand.

=cut

sub roledir {
   my ($self, $dir, $parms) = @_;
   my $transmogrifiers = $parms->{'transmogrify'};
   $parms->{'transmogrify'} = undef;

   my $rd = $self->readdir_q($dir, $parms);

   $parms = {} unless defined $parms;
   my $ruleset = $parms->{'roles'} || [['.']]; # The default is just a role of '.' that everything will match.
   
   my $base_iter = $rd->transmogrify (['rolecalc', $ruleset]);
   if ($transmogrifiers) {
      return $base_iter->transmogrify(@$transmogrifiers);
   } else {
      return $base_iter;
   }
}

=head1 WALKING

=head2 walk (dir, parms)

=cut

sub walk {
   my ($self, $dir, $parms, $level) = @_;
   my $underlying;
   my $transmogrifiers = $parms->{'transmogrify'};
   $parms->{'transmogrify'} = undef;
   
   if (exists $parms->{'roles'}) {
      $underlying = $self->roledir($dir, $parms);
   } else {
      $underlying = $self->readdir_q($dir, $parms);
   }
   my $show_level = 1;
   $show_level = 0 if $parms->{'no_level_field'};
   my $show_path = 1;
   $show_path = 0 if $parms->{'no_path_field'};
   my $newfields = [ $show_path ? ('path') : (), $show_level ? ('level') : () ];

   $level = 0 unless defined $level;
   my $maxlevel = $parms->{'maxlevel'};
   $maxlevel = 0 if $parms->{'nowalk'}; # Simple pruning in role-based walkers.
   
   my $stopwalk = $parms->{'stopwalk'};
   my @pparms;
   if ($stopwalk) {
      ($stopwalk, @pparms) = @$stopwalk;
   }
   
   my $pruning_parms = scalar(@pparms) ? \@pparms : ['name'];
   
   my $base_iter = $underlying->transmogrify(['walk', $self->_walker_builder($dir, $level, $show_path, $show_level, $maxlevel, $stopwalk, $parms), $newfields, @$pruning_parms]);
   if ($transmogrifiers) {
      return $base_iter->transmogrify(@$transmogrifiers);
   } else {
      return $base_iter;
   }
}

sub _walker_builder {
   my ($self, $dir, $level, $show_path, $show_level, $maxlevel, $stopwalk, $parms) = @_;
   
   # We are returning a codref factory that the walk transmogrifier builder will call, to get the coderef that
   # actually does the transmogrification of individual records.
   sub {
      my ($fields, $newfields, $infields, $offsets) = @_;
      my ($name_offset, $item_offset) = Iterator::Records::_find_offsets ($fields, ('name', 'item'));
      
      sub {
         my $rec = shift;
         
         my $item = $rec->[$item_offset];
         my $name = $rec->[$name_offset];
         my $path = catfile ($dir, $name);
         
         my $iterator = undef;
         if (    $item eq '+'
             and $name !~ /^\.+$/      # Don't walk into parent or self, if the underlying lister isn't clean!
             and (not defined $maxlevel or $level < $maxlevel)
            ) {
            if ($stopwalk) {
               my @swparms = map { $rec->[$_] } @$offsets;
               if (not $stopwalk->(@swparms)) {
                  $iterator = $self->walk ($path, $parms, $level + 1);
               }
            } else {
               $iterator = $self->walk ($path, $parms, $level + 1);
            }
         }
         
         ([ $show_path ? ($path) : (), $show_level ? ($level) : (), @$rec ],
          $iterator ? ($iterator) : ()
         );
      }
   }
}


package Iterator::Records::Files::Iterator;
use parent 'Iterator::Records';
use Iterator::Records::Files;
use Carp;
use Data::Dumper;

sub _find_offsets {
   my $field_list = shift;
   my $size = scalar @{$field_list}-1;
   my @output;
   foreach my $f (@_) {
      my ($index) = grep { $field_list->[$_] eq $f } (0 .. $size);
      croak "Unknown field '$f' used in role calculation rule" unless defined $index;
      push @output, $index;
   }
   @output;
}

sub _rc_calc {
   my $rec = shift;
   my $sub = shift;
   my @values = map { $rec->[$_] } _find_offsets ([Iterator::Records::Files::file_fields()], @_);
   return $sub->(@values);
}

sub _rc_match {
   my $rec = shift;
   my $pattern = shift;
   my @values = ( $rec->[1] =~ $pattern );
   if (@values) {
      my $v = {};
      while (my $field = shift @_) {
         if (@values) {
            $v->{$field} = shift @values;
         } else {
            $v->{$field} = '';
         }
      }
      return $v;
   } else {
      return 0;
   }
}

sub _rc_name {
   my $rec = shift;
   foreach my $v (@_) {
      return 1 if $rec->[1] eq $v;
   }
   return 0;
}

sub _rc_ext {
   my $rec = shift;
   foreach my $v (@_) {
      return 1 if $rec->[2] eq $v;
   }
   return 0;
}

sub _rc_file {
   my $rec = shift;
   $rec->[0] eq '-';
}

sub _rc_dir {
   my $rec = shift;
   $rec->[0] eq '+';
}

our $rolecalcers = {
   'calc' => \&_rc_calc,
   'match' => \&_rc_match,
   'name' => \&_rc_name,
   'ext' => \&_rc_ext,
   'file' => \&_rc_file,
   'dir' => \&_rc_dir,
};

sub _find_role_calcer {
   croak "Unknown role calc rule '" . $_[0] . "'" unless exists $rolecalcers->{$_[0]};
   $rolecalcers->{$_[0]};
}

sub _run_rules {
   my ($rules, $rec) = @_;
   ROLE: foreach my $rule (@$rules) {
      my ($role, @clauses) = @$rule;
      my $values = {};
      CLAUSE: foreach my $clause (@clauses) {
         my ($check, @parms) = @$clause;
         my $rc = _find_role_calcer ($check);
         my $result = $rc->($rec, @parms);
         next ROLE unless $result;
         if (ref $result) {
            $values = { (%$values, %$result) };
         }
      }
      return ($role, $values);
   }
   return '', {};
}

sub _rolecalc {
   my $fieldlist = shift;
   my $rules = shift;
   
   sub {
      my $rec = shift;
      my ($role, $values) = _run_rules($rules, $rec);
      [$role, @$rec, $values];
   }
}

sub _rolecalc_fields {
   my $fields = shift;
   my @fields = ('role', @$fields, 'value_bag');
   \@fields;
}


sub _getvalue_fields {
   my $fields = shift;
   my @fields = (@$fields, @_);
   \@fields;
}

sub _getvalue {
   my $fields = shift;
   my ($fieldno) = Iterator::Records::_find_offsets ($fields, 'value_bag');
   my $vals = "\$rec->[$fieldno]->{"  . join ("{, \$rec->[$fieldno]->{", @_) . '}';
   
   my $sub = <<"EOF";
      sub {
         my \$rec = shift;
         return [@\$rec, $vals ];
      }
EOF
   #print STDERR $sub;
   eval $sub;
}

our $transmogrifiers = {
  'rolecalc' => [\&_rolecalc_fields, \&_rolecalc],
  'getvalue' => [\&_getvalue_fields, \&_getvalue], 
};
sub _find_transmogrifier {
   return $_[0]->_find_core_transmogrifier ($_[1]) unless exists $transmogrifiers->{$_[1]};
   @{$transmogrifiers->{$_[1]}};
}


=head1 AUTHOR

Michael Roberts, C<< <michael at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Iterator-Records-Files at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Iterator-Records-Files>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Iterator::Records::Files


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Iterator-Records-Files>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Iterator-Records-Files>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Iterator-Records-Files>

=item * Search CPAN

L<http://search.cpan.org/dist/Iterator-Records-Files/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2019 Michael Roberts.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Iterator::Records::Files
