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

my $test_count = 0;
my @failed_files;

File::Path::mkpath($output);
chdir($root);

for my $filename (@fullnames) {
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

  my @common_opts = ("-Wall -pedantic -fsanitize=address -I.", @args);
  push @common_opts, "-lstdc++ -std=c++11";
  push @common_opts, "-include $root/tests/test.h";
  push @common_opts, $filename;

  my $file_failed = 0;
  $test_count += 1;

  push @variants, '' unless @variants;
  my $variant_index = 0;

  for my $variant (@variants) {
    $variant_index += 1;
    my $output_name = "$output/$test_filename" . ((@variants > 1) ? "-$variant_index" : "");

    my @cmd = ($cc, @common_opts);
    push @cmd, $variant if $variant;
    push @cmd, "-o $output_name";
    push @cmd, "&& $output_name";

    say "==> $0 $filename" . ($variant ? " [$variant]" : "");

    my $cmd = join(' ', @cmd);
    if (0 != system($cmd)) {
      $file_failed = 1;
      say "\nFailed command: $cmd\n";
      last;
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
  exit(-1);
}
elsif ($test_count > 0) {
  say "All tests OK";
}
else {
  say "No tests to run";
}

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
