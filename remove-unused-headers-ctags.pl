#!/usr/bin/env perl

use Data::Dumper;
use File::Basename;
use File::Slurp;
use strict;
use warnings;

open (my $ctags_db, '<:mmap', 'tags') or die "Cannot open tags file: $!";

my %skippedFiles = (
    'Source/WTF/wtf/Compiler.h' => 1,
    'Source/WTF/wtf/Platform.h' => 1,
    'Source/WTF/wtf/WindowsExtras.h' => 1,
    'Source/WTF/wtf/dtoa.h' => 1,
);

my %ignoredHeaders = (
    'config.h' => 1,
    'wtf/RetainPtr.h' => 1,
    'wtf/Assertions.h' => 1,
    'wtf/Atomics.h' => 1,
    'wtf/StdLibExtras.h' => 1,
    'wtf/MathExtras.h' => 1,
    'wtf/text/IntegerToStringConversion.h' => 1,
    'wtf/text/WTFString.h' => 1,
    'Settings.h' => 1,
    'GraphicsContext3D.h' => 1
);

sub headerIsIgnored {
    my $header = shift;

    return 1 if (exists $ignoredHeaders{$header});

    return 1 if $header =~ m{^runtime/.*Array.h$};

    return 1 if $header =~ m{^unicode/} || $header =~ m{^sys/} || $header =~ m{^mach/} || $header =~ m{^System/} || $header =~ m{^Security/} || $header =~ m{^dispatch/} || $header =~ m{^CommonCrypto/} || $header =~ m{^machine/} || $header =~ m{^objc/} || $header =~ m{^gio/} || $header =~ m{^wtf/spi/} || $header =~ m{CoreFoundation/} || $header =~ m{^xpc/} || $header =~ m{^mach-o/} || $header =~ m{^os/} || $header =~ m{^WebKitAdditions/};
    return 1 if $header =~ /Inlines\.h$/ || $header =~ /intrin\.h$/ || $header =~ /Hash\.h/;
    return $header =~ /^std/ || $header !~ /\.h$/;
}

my %genericWords = (
    'get' => 1,
    'add' => 1,
    'append' => 1,
    'begin' => 1,
    'count' => 1,
    'color' => 1,
    'client' => 1,
    'clear' => 1,
    'clearAll' => 1,
    'child' => 1,
    'children' => 1,
    'core' => 1,
    'copy' => 1,
    'convert' => 1,
    'context' => 1,
    'contains' => 1,
    'create' => 1,
    'ios' => 1,
    'isEmpty' => 1,
    'isValid' => 1,
    'isType' => 1,
    'index' => 1,
    'invert' => 1,
    'image' => 1,
    'identifier' => 1,
    'icon' => 1,
    'height' => 1,
    'hash' => 1,
    'end' => 1,
    'element' => 1,
    'dump' => 1,
    'first' => 1,
    'from' => 1,
    'fromString' => 1,
    'decode' => 1,
    'encode' => 1,
    'data' => 1,
    'get' => 1,
    'size' => 1,
    'clear' => 1,
    'view' => 1,
    'version' => 1,
    'verbose' => 1,
    'velocity' => 1,
    'vector' => 1,
    'variant' => 1,
    'variants' => 1,
    'variables' => 1,
    'value' => 1,
    'values' => 1,
    'visit' => 1,
    'use' => 1,
    'url' => 1,
    'width' => 1,
    'which' => 1,
    'weight' => 1,
    'kit' => 1,
    'kind' => 1,
    'key' => 1,
    'iterator' => 1,
    'item' => 1,
    'label' => 1,
    'last' => 1,
    'left' => 1,
    'length' => 1,
    'next' => 1,
    'name' => 1,
    'move' => 1,
    'message' => 1,
    'pair' => 1,
    'parent' => 1,
    'paint' => 1,
    'properties' => 1,
    'position' => 1,
    'port' => 1,
    'pop' => 1,
    'put' => 1,
    'queue' => 1,
    'request' => 1,
    'response' => 1,
    'replace' => 1,
    'renderer' => 1,
    'remove' => 1,
    'release' => 1,
    'ref' => 1,
    'rect' => 1,
    'reset' => 1,
    'resize' => 1,
    'response' => 1,
    'result' => 1,
    'right' => 1,
    'scale' => 1,
    'scheme' => 1,
    'scope' => 1,
    'set' => 1,
    'setValue' => 1,
    'setX' => 1,
    'setX1' => 1,
    'setX2' => 1,
    'setY' => 1,
    'setY1' => 1,
    'setY2' => 1,
    'source' => 1,
    'string' => 1,
    'size' => 1,
    'swap' => 1,
    'table' => 1,
    'tag' => 1,
    'top' => 1,
    'toJS' => 1,
    'toString' => 1,
    'target' => 1,
    'text' => 1,
    'type' => 1,
    'title' => 1,
    'true' => 1,
    'transform' => 1,
    'translate' => 1,
    'transitions' => 1,
    'Base' => 1,
    'base' => 1,
    'Yes' => 1,
    'No' => 1,


    'priv' => 1,
    'createStructure' => 1,
    'safeToCompareToEmptyOrDeleted' => 1, # ???
);

my %identifiersForHeaderCache;

sub identifiersForHeader {
    my $header = shift;

    if (exists $identifiersForHeaderCache{$header}) {
        return @{$identifiersForHeaderCache{$header}};
    }

    my @result;
    my %seenTags;

    # Search ctags
    seek($ctags_db, 0, 0) or die "Cannot rewind tags file: $!";
    for my $line (<$ctags_db>) {
        # Roughly search for target file name
        next if index($line, $header) == -1;

        # Skip ctags headers
        next if $line =~ /^!/;

        my ($tag, $filename, $kind) = (split "\t", $line, 5)[0, 1, 3];

        # Filename should match exactly
        next unless ($filename eq $header) || $filename =~ m{/$header$};

        # Skip seen tag
        next if exists $seenTags{$tag};
        $seenTags{$tag} = 1;

        # Exclude tag which is too generic
        next if length($tag) < 3;
        next if exists $genericWords{$tag};

        # Do not include private fields
        next if $line =~ /\baccess:(?:private|protected)\b/; # index($line, 'access:private') != -1;
        next if $tag =~ /^m_/;

        # Skip dtors
        next if $tag =~ /^~/;
        # Skip operators
        next if $tag =~ /^operator /;

        # Skip preprocessor guards
        next if ($kind eq 'd') && ($tag =~ /_h$/);

        push @result, $tag;
    }

    # Save result in cache
    $identifiersForHeaderCache{$header} = \@result;

    #print "$header --> @result\n";
    return @result;
}

sub parseFile {
    my ($lines, $headers) = @_;
    my %identifiers;

    LINE: for my $line (@$lines) {
        if ($line =~ /^#include [<"](\S+)[>"]/) {
            my $header = $1;
            if (headerIsIgnored($header)) {
                print "Ignored header: $header\n";
                next LINE;
            }

            my @ids = identifiersForHeader($header);
            if (!@ids) {
                print "Skipping header which has no identifiers: $header\n";
                next LINE;
            }

            $headers->{$header} = \@ids;
            for my $i (@ids) {
                $identifiers{$i} = $header;
            }
            next LINE;
        }

        my @ids = keys %identifiers;
        for my $i (@ids) {
            if (exists $identifiers{$i} && $line =~ /\b$i\b/) {
                my $header = $identifiers{$i};
                print "Found tag $i from $header\n";
                my @identifiersFromHeader = @{$headers->{$header}};
                for (@identifiersFromHeader) {
                    delete $identifiers{$_};
                }
                delete $headers->{$header};
            }
        }
    }
}

sub writeFile {
    my ($fh, $lines, $headers) = @_;

    LINE: for my $line (@$lines) {
        if ($line =~ /^#include [<"](\S+)[>"]/) {
            next LINE if (exists $headers->{$1});
        }
        print $fh $line;
    }
}

sub processFile {
    my $filename = shift;

    if (open my $fh, '<', $filename) {
        my %headersToRemove;
        my @lines = <$fh>;
        close $fh;

        #print "File: $filename\n";
        parseFile(\@lines, \%headersToRemove);

        if (keys %headersToRemove) {
            if (open my $fh_w, '>', $filename) {
                print "Fixing headers in $filename\n";
                writeFile($fh_w, \@lines, \%headersToRemove);
                close $fh_w;
            } else {
                warn "Could not open $filename for writing: $!";
            }
        }
    } else {
        warn "Could not open $filename: $!";
    }
}

for my $filename (@ARGV) {
    next if exists $skippedFiles{$filename} || $filename =~ m{dtoa/} || $filename =~ m{ForwardingHeaders/} || $filename =~ /config\.h$/ || $filename =~ /Inlines\.h$/;
    processFile($filename);
}
