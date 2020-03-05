#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use Cwd;
use Digest::MD5;
use File::Basename;
use File::Path;

my $cc = $ENV{CC} || 'clang';
my $root = Cwd::abs_path(File::Basename::dirname($0) . "/..");
my $test_tmp = $root . "/tmp/tests";
my $output = $test_tmp . "/t";
my $dir = Cwd::getcwd();
my @fullnames = map { Cwd::abs_path($_) } @ARGV;

my $exit_code = 0;
my $test_count = 0;
my @failed_files;

File::Path::mkpath($output);
chdir($root);

for my $filename (@fullnames) {
  last if $exit_code;
  next unless $filename;
  next if -d $filename || $filename =~ /\.(h|txt|pl)$/i;

  my $contents = read_file($filename);
  if (!defined $contents) {
    say qq/WARN: file "$filename" cannot be opened: $!/;
    next;
  }

  my @args = scan_source($contents, '\\+');
  my @variants = scan_source($contents, '\\?');

  my $test_filename = ($filename =~ /\/tests\/(.+)/) ? $1 : Digest::MD5::md5_hex($contents);
  $test_filename =~ s/[\W_]+/-/g;

  my @common_opts = ("-Wall -pedantic -fsanitize=address -I. -Itests", @args);
  push @common_opts, "-lstdc++ -std=c++11";
  push @common_opts, shell_escape($filename);

  my $file_failed = 0;
  $test_count += 1;

  push @variants, '' unless @variants;
  my $variant_index = 0;

  for my $variant (@variants) {
    $variant_index += 1;
    my $output_name = shell_escape("$output/$test_filename" . ((@variants > 1) ? "-$variant_index" : ""));

    my @cmd = ($cc, @common_opts);
    push @cmd, $variant if $variant;
    push @cmd, "-o $output_name";
    push @cmd, "&& $output_name";

    say "==> $0 " . shell_escape($filename) . ($variant ? " [$variant]" : "");

    my $cmd = join(' ', @cmd);
    my $ret = system($cmd);
    if ($ret) {
      say "\n[$ret] $cmd\n";
      last if 2 != $ret;
      $file_failed = 1;
      $exit_code = $ret;
    }
  }

  if ($file_failed) {
    push @failed_files, $filename;
  }
}

chdir($dir);
write_file($test_tmp . "/t-failed", join(' ', @failed_files));

if (@failed_files) {
  say "There were test failures:";
  say " * $_" for @failed_files;
}
elsif ($test_count > 0) {
  say "All tests OK";
}
else {
  say "No tests to run";
}

exit($exit_code);

sub read_file {
  my $filename = shift;
  return unless open(my $fh, '<', $filename);
  local $/ = undef;
  return <$fh>;
}

sub write_file {
  my $filename = shift;
  return unless open(my $fh, '>', $filename);
  return print $fh $_[0];
}

sub scan_source {
  my ($contents, $type) = @_;
  my @result;
  push @result, $1 while $contents =~ /^\s*\/\/[ \t]*$type[ \t]*([^\r\n]+)/mg;
  return @result;
}

sub shell_escape {
  my $string = shift;
  return "''" if !defined $string || length($string) == 0;
  die "No way to quote string containing null (\\000) bytes" if $string =~ /\x00/;
  return $string if $string =~ /^[\@\w\/\-\.]+$/;
  $string =~ s/'/'\\''/g;
  return "'$string'";
}
